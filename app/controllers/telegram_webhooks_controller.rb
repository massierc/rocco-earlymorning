class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  include BusinessDate
  include Utils
  context_to_action!

  before_action :set_user

  def set_user
    @bot = Telegram.bot
    @message = ActiveSupport::HashWithIndifferentAccess.new(payload)
    @user = User.find_or_initialize_by(uid: @message['from']['id'], username: @message['from']['username'])
    @user.update(setup: 3) unless @user.persisted?
    if @user.save
      @work_day = @user.find_or_create_workday
    else
      attribute = @user.errors.messages.first[0].to_s.capitalize
      error = @user.errors.messages.first[1][0]
      @bot.send_message(chat_id: @user.uid, text: "❌ #{attribute} #{error}")
    end
  end

  def message(_message)
    return unless @user.persisted?
    return unless @user.company_id == 0 || debugging_with('ElenorGee', 'marinamo')
    @work_day = @user.find_or_create_workday
    msg = {
      user: @user,
      context: @work_day.aasm_state,
      message: _message
    }
    if @user.setup > 0
      if @user.setup == 3
        start
      else
        handle_setup
      end
    else
      if @user.company_id == 0
        handle_timesheet
      else
        handle_message(msg)
      end
    end
  end

  def callback_query(data)
    data = JSON.parse(data)
    return if data['state'] != @work_day.aasm_state
    msg_id = payload['message']['message_id']
    @bot.delete_message(chat_id: @user.uid, message_id: msg_id)
    @work_day = @user.find_or_create_workday
    manage_worksession(data)
    ws = @work_day.work_sessions.find_by_end_date(nil)
    if ws && @work_day.aasm_state == 'waiting_for_client'
      if ws.client.nil?
        @bot.send_message(chat_id: @user.uid, text: 'Scusa non ho capito 😕')
        @work_day.wait_for_activity!
      end
    end
    handle_state(@work_day.aasm_state) unless still_working?(data) || lunch?(data) || workday_finished?(data) || new_project?(data)
  end

  def premimimi
    if @user.setup > 0
      handle_setup
    else
      AskJob.perform_later(@user.uid) if @user.company_id == 0
    end
  end

  def nwo(*args)
    admins = %w[gildof riccardocattaneo17 massierc]
    user = @message['from']['username']
    if admins.include? user
      if args.length === 0
        RiccardoJob.perform_later
        respond_with :message, text: "Ciao #{user}, job NWO avviato con successo per il mese in corso 👍"
      elsif is_month?(args[0])
        month = args[0].strip.downcase.capitalize
        RiccardoJob.perform_later(month)
        respond_with :message, text: "Ciao #{user}, job NWO avviato con successo per #{args[0]} #{Date.today.year} 👍"
      else
        respond_with :message, text: "#{user}, #{args.join(' ')} non mi sembra un mese, ritenta!"
      end
    else
      respond_with :message, text: "#{user} /nwo è un comando riservato, non sei admin."
      respond_with :message, text: "L'incidente verrà riportato."
      sleep(5)
      respond_with :message, text: '..scherzooo!'
    end
  end

  def unbillable
    admins = %w[gildof riccardocattaneo17]
    if admins.include? @message['from']['username']
      UnbillableJob.perform_later
      respond_with :message, text: "Ciao #{@message['from']['username']}, job Unbillable avviato con successo 💩"
    else
      respond_with :message, text: "#{@message['from']['username']} /unbillable è un comando riservato, non sei admin."
      respond_with :message, text: "L'incidente verrà riportato."
      sleep(5)
      respond_with :message, text: '..scherzooo!'
    end
  end

  def pigri
    admins = %w[gildof riccardocattaneo17]
    if admins.include? @message['from']['username']
      respond_with :message, text: "Ciao #{@message['from']['username']}, ecco la lista: "
      I18n.locale = :it
      skips = %w[FilippoLocoro kiaroskuro]
      lazy = User.where(company_id: 0).order(updated_at: :desc).collect do |u|
        data = I18n.l(u.updated_at.to_datetime, format: '%A %d %B %H:%M')
        next if skips.include?(u.username)
        "#{!u.name.blank? ? u.name : u.username} - #{data}"
      end.join("\n")

      respond_with :message, text: lazy
    else
      respond_with :message, text: "#{@message['from']['username']} /pigri è un comando riservato, non sei admin."
      respond_with :message, text: "L'incidente verrà riportato."
      sleep(5)
      respond_with :message, text: '..scherzooo!'
    end
  end

  def teamrocco(*)
    if @user.special
      @user.update(special: false)
      respond_with :message, text: 'Adios!'
    else
      save_context :teamrocco
      respond_with :photo, photo: File.open(Rails.root.join('public', 'password.jpg')), caption: "Parola d\'ordine?"
    end
  end

  context_handler :teamrocco do |*words|
    if words[0].downcase.include?('guazzabuglio')
      @user.update(special: true)
      respond_with :document, document: File.open(Rails.root.join('public', 'rocco', 'walking.gif')), caption: 'Welcome!'
    else
      respond_with :document, document: File.open(Rails.root.join('public', 'wrong_password.gif')), caption: 'Password sbagliata!'
    end
  end

  def start(*)
    return unless @user.persisted?
    respond_with :message, text: "Ciao #{@message[:from][:first_name]} 😃"
    respond_with :message, text: 'Prima di cominciare ho bisogno che mi autorizzi a modificare il tuo TimeSheet, per favore clicca su questo link ed in seguito digita il codice di autorizzazione che ti verrà fornito:'
    @url = Authorizer.new(@message[:from][:id]).get_url
    respond_with :message, text: @url
    @user.update(setup: 2)
  end

  def auth
    respond_with :message, text: 'Clicca su questo link e in seguito digita il codice di autorizzazione che ti verrà fornito:'
    @url = Authorizer.new(@message[:from][:id]).get_url
    respond_with :message, text: @url
    @user.update(setup: 2)
  end

  def nota(*)
    save_context :nota

    respond_with :message, text: "#{@message[:from][:first_name]} scrivi ora la nota per #{@user.who}"
  end

  context_handler :nota do |*words|
    user_service = Authorizer.new(@message[:from][:id])
    user_service.create_note(words.join(' '))
    respond_with :message, text: 'Nota aggiunta correttamente'
  end

  private

  def handle_message(msg)
    case msg[:context]
    when 'waiting_for_morning'
      respond_with :message, text: 'Ciao 👋'
      handle_state(@work_day.aasm_state)
    when 'waiting_for_new_client'
      client = msg[:message]['text']
      @user.active_worksession.update(client: client)
      respond_with :message, text: "▶️ aggiunto #{client} alla tua lista di clienti"
      @work_day.wait_for_client!
      handle_state(@work_day.aasm_state)
    when 'waiting_for_end_of_session'
      @user.destroy_scheduled_jobs('WorkTimerJob').perform_now(@user.id)
    when 'workday_finished'
      respond_with :message, text: "Ehi #{msg[:message]['from']['username']}, la giornata è finita!"
      respond_with :message, text: 'Ci risentiamo domani 🙂'
      nil
    else
      respond_with :message, text: "Scusa, non capisco cosa intendi con #{msg[:message]['text']} 🤔"
      nil
    end
  end

  def debugging_with(*users)
    if users.include? @message['from']['username']
      true
    else
      respond_with :message, text: "Scusa, sono in manutenzione. Tornerò presto 🍆"
      false
    end
  end

  def manage_worksession(data)
    if session_finished?(data)
      @user.close_active_sessions
    elsif still_working?(data)
      @bot.send_message(chat_id: @user.uid, text: 'Ok, a dopo!')
    elsif lunch?(data)
      @user.close_active_sessions
      create_lunch
    elsif workday_finished?(data)
      @work_day.end!
      @user.close_active_sessions
      @work_day.send_evening_recap
      @bot.send_message(chat_id: @user.uid, text: 'Tra poco aggiorno il tuo timesheet. Buona serata 🍻')
      next_business_day = next_business_day(DateTime.current)
      next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 9, 30)
      @user.destroy_scheduled_jobs('WorkTimerJob')
      @user.destroy_scheduled_jobs('HelloJob').set(wait_until: next_business_day).perform_later(@user.uid)
      @user.destroy_scheduled_jobs('UpdateTimesheetsJob').perform_later(@user.id)
      if @user.special
        r = random_rocco
        if r.include?('gif')
          @bot.send_document(chat_id: @user.uid, document: File.open(r))
        else
          @bot.send_photo(chat_id: @user.uid, photo: File.open(r))
        end
      end
    elsif new_project?(data)
      @work_day.wait_for_new_client!
      @bot.send_message(chat_id: @user.uid, text: 'Su cosa lavori?')
    elsif new_activity?(data)
      @work_day.wait_for_morning!
    elsif ask_again?(data)
      @work_day.wait_for_end_of_session!
    else
      update_worksession(data)
    end
  end

  def handle_state(state)
    sh = StateHandler.new(user: @user, work_day: @work_day)
    sh.public_send(state)
  end

  def update_worksession(data)
    if data['state'] == 'waiting_for_activity'
      @user.work_sessions.create(start_date: DateTime.current, work_day: @work_day, activity: data['value'])
      respond_with :message, text: "▶️ lavori da: #{data['value']}"
    elsif data['state'] == 'waiting_for_client'
      @user.active_worksession.update(client: data['value'])
      respond_with :message, text: "▶️ stai lavorando su: #{data['value']}"
    end
  end

  def session_finished?(data)
    data['state'] == 'waiting_for_end_of_session' && data['value'] == 'finished'
  end

  def still_working?(data)
    data['state'] == 'waiting_for_end_of_session' && data['value'] == 'still_working'
  end

  def lunch?(data)
    data['state'] == 'waiting_for_end_of_session' && data['value'] == 'lunch'
  end

  def workday_finished?(data)
    data['state'] == 'waiting_for_confirmation' && data['value'] == 'good_night'
  end

  def new_project?(data)
    data['state'] == 'waiting_for_client' && data['value'] == 'new_proj'
  end

  def new_activity?(data)
    data['state'] == 'waiting_for_user_input' && data['value'] == 'add_new_activity'
  end

  def ask_again?(data)
    data['state'] == 'waiting_for_confirmation' && data['value'] == 'ask_again'
  end

  def create_lunch
    @user.work_sessions.create(start_date: DateTime.current, work_day: @work_day, client: 'Pranzo', activity: '')
    @bot.send_message(chat_id: @user.uid, text: 'Buon appetito! 🍔')
  end

  def handle_timesheet
    user_service = Authorizer.new(@message[:from][:id])
    user_projects = user_service.project_cells

    if @message['text'] =~ /stop/i
      respond_with :message, text: "Richiesta fermata, see you #{next_business_day(DateTime.current).strftime('%A')}"
      @user.update(level: 0)
      return
    end

    case @user.level
    when 3
      @user.update(level: 2, who: @message['text'])

      activities = user_service.list_activities(user_projects, @user.who)
      respond_with :message, text: 'Quale activity?', reply_markup: {
        keyboard: activities,
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }

    when 2
      @user.update(level: 1, what: @message['text'])
      # activities = user_service.list_activities(user_projects, @user.who)
      respond_with :message, text: 'E per quanto tempo?', reply_markup: {
        # keyboard: [[@user.howmuch.to_s, '8'], ['stop']],
        keyboard: [%w[0.5 1 2 3], %w[4 5 6 7], %w[8 stop]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }

    when 1
      @user.update(level: 0, howmuch: @message['text'])
      Authorizer.new(@message[:from][:id]).update_timesheet(@user)
      m = "Grazie, il tuo TimeSheet è stato aggiornato, premi /nota per aggiungere un commento.
Se vuoi aggiungere altre ore di lavoro /premimimi!"
      if @user.special
        r = random_rocco
        if r.include?('gif')
          respond_with :document, document: File.open(r), caption: m
        else
          respond_with :photo, photo: File.open(r), caption: m
        end
      else
        respond_with :message, text: m
      end
    when 0
      respond_with :message, text: 'Ma lavori ancora? :P Se vuoi aggiungere altre ore di lavoro /premimimi!'
    end
  end

  def handle_setup
    case @user.setup
    when 5
      text = @message['text'].capitalize.chomp.strip
      if %w[Mono Pluri].include? text
        text == 'Mono' ? @user.update(company_id: 2, setup: 0) : @user.update(company_id: 1, setup: 0)
        respond_with :message, text: 'Grazie mille, il setup è completo!'
        handle_state(@work_day.aasm_state)
      else
        respond_with :message, text: 'Scusa, non ho capito: sei mono o pluri cliente?', reply_markup: {
          keyboard: [%w[Mono Pluri]],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
        }
      end
    when 4
      if %w[EM EMF].include? @message['text'].upcase.chomp
        if @message['text'] == 'EM'
          respond_with :message, text: 'Perfetto, e sei mono o pluri cliente?', reply_markup: {
            keyboard: [%w[Mono Pluri]],
            resize_keyboard: true,
            one_time_keyboard: true,
            selective: true
          }
          @user.update(setup: 5)
        else
          @user.update(company_id: 0, setup: 0)
          respond_with :message, text: 'Grazie mille, ti contatterò alle 19:00. Vuoi segnare il tuo TimeSheet ora? /premimimi!'
        end

        if @user.company_id == 0
          next_business_day = next_business_day(DateTime.current)
          next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 19, 0o0)
          job = AskJob.set(wait_until: next_business_day).perform_later(@user.uid)
          @user.update(jid: job.job_id, level: 3)
        else
          @user.update(level: 0)
        end

      else
        respond_with :message, text: 'Scusa non ho capito, sei EM o EM Finance (EM/EMF)?', reply_markup: {
          keyboard: [%w[EM EMF]],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
        }
      end
    when 2
      @auth = Authorizer.new(@message['from']['id']).store_auth(@message[:text])
      if @auth == 0 || @auth.nil?
        respond_with :message, text: 'Codice errato, per favore riprova:'
        @url = Authorizer.new(@message['from']['id']).get_url
        respond_with :message, text: @url
        @user.update(setup: 2)
      else
        respond_with :message, text: 'Grazie sei stato autenticato correttamente' unless @user.sheet_id
        respond_with :message, text: "Ora ho bisogno dell\'indirizzo del tuo TimeSheet su Google Drive"
        @user.update(setup: 1)
      end
    when 1
      sheet_id = @message['text'].split('spreadsheets/d/')[1].split('/')[0]
      @user.update(sheet_id: sheet_id)

      @user.update(setup: 4)
      respond_with :message, text: 'Grazie mille, ora mi serve sapere se lavori per EM o EM Finance', reply_markup: {
        keyboard: [%w[EM EMF]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    end
  end

  def random_rocco
    Dir[Rails.root.join('public', 'rocco', '*')].sample
  end
end
