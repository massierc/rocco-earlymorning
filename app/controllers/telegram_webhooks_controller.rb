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
    @user.setup = 3 unless @user.persisted?
    @user.save
    @work_day = @user.work_days.find_by_date(Date.current)
  end

  def message(_message)
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
        handle_message(_message['text'])
      end
    end
  end

  def handle_message(msg)
    if msg_in_scope?(msg)
      @work_day = WorkDay.create(user: @user, date: Date.today) unless @work_day
      respond_with :message, text: 'Ciao 👋' if msg.match(/ciaoo*/i) 
      sh = StateHandler.new(user: @user, work_day: @work_day)
      sh.public_send(@work_day.aasm_state)
    else
      respond_with :message, text: "Scusa, non capisco cosa intendi con #{msg} 🤔"
    end
  end

  def msg_in_scope?(msg)
    msg.match(/ciaoo*/i) || msg.match(/finito/i) || msg.match(/finish/i) || msg.match(/fatto/i) || msg.match(/done/i)
  end

  def callback_query(data)
    @work_day = @user.work_days.find_by_date(Date.current)
    @message_id = payload['message']['message_id']
    data = JSON.parse(data)
    manage_worksession(data)
    sh = StateHandler.new(user: @user, message_id: @message_id, work_day: @work_day)
    sh.public_send(data['state']) unless still_working?(data) || workday_finished?(data) || lunch?(data)
  end

  def manage_worksession(data)
    if session_finished?(data)
      end_worksession
    elsif still_working?(data)
      msg = 'Ok, a dopo!'
      close_kb_and_send_msg(msg)
    elsif lunch?(data)
      end_worksession
      create_lunch
    elsif workday_finished?(data)
      msg = 'Ok, tra poco aggiorno il tuo timesheet. Buona serata 🍻'
      close_kb_and_send_msg(msg)
      @user.delay.update_timesheets
      next_business_day = next_business_day(DateTime.current)
      next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 9, 30)
      HelloJob.set(wait_until: next_business_day).perform_later(@user.uid)
    else
      update_worksession(data)
    end
  end

  def close_kb_and_send_msg(msg)
    @bot.delete_message(chat_id: @user.uid, message_id: @message_id)
    @bot.send_message(chat_id: @user.uid, text: msg)
  end

  def update_worksession(data)
    if data['state'] == 'waiting_for_activity'
      @user.work_sessions.create(start_date: DateTime.current, work_day: @work_day, activity: data['value'])
      respond_with :message, text: "▶️ lavori da: #{data['value']}"
    elsif data['state'] == 'waiting_for_client'
      @user.active_worksession.update(client: data['value'])
      respond_with :message, text: "▶️ stai lavorando su: #{data['value']}"
    else
      return
    end
  end

  def end_worksession
    @user.close_active_sessions
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
    data['state'] == 'waiting_for_user_input' && data['value'] == 'good_night'
  end

  def premimimi
    if @user.setup > 0
      handle_setup
    else
      AskJob.perform_later(@user.uid)
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
          respond_with :message, text: "Ciao #{user}, job NWO avviato con successo per #{args[0]} #{Date.today.year.to_s} 👍"
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
    respond_with :message, text: "Ciao #{@message[:from][:first_name]} 😃"
    respond_with :message, text: 'Prima di cominciare ho bisogno che mi autorizzi a modificare il tuo TimeSheet, per favore clicca su questo link'
    respond_with :message, text: 'ed in seguito digita il codice di autorizzazione'
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

  def create_lunch
    @user.work_sessions.create(start_date: DateTime.current, work_day: @work_day, client: 'Pranzo', activity: '')
    msg = 'Buon appetito! 🍔'
    close_kb_and_send_msg(msg)
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
    when 4
      if %w[EM EMF].include? @message['text'].upcase.chomp
        if @message['text'] == 'EM'
          @user.update(company_id: 1, setup: 0)
          respond_with :message, text: 'Grazie mille, il setup è completo!'
        else
          @user.update(company_id: 0, setup: 0)
          respond_with :message, text: 'Grazie mille, ti contatterò alle 19:00. Vuoi segnare il tuo TimeSheet ora? /premimimi!'
        end

        if @user.company_id == 0
          next_business_day = next_business_day(DateTime.current)
          next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 19, 00)
          job = AskJob.set(wait_until: next_business_day).perform_later(@user.uid)
          @user.update(jid: job.job_id, level: 3)
        else
          @user.update(level: 0)
        end

      else
        respond_with :message, text: 'Scusa non ho capito, sei EM o EM Finance (EM/EMF)', reply_markup: {
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
        respond_with :message, text: "Ora mi serve solo l\'indirizzo del tuo TimeSheet su Google Drive"
        @user.update(setup: 1)
      end
    when 1
      sheet_id = @message['text'].split('/').max_by(&:length)
      @user.update(sheet_id: sheet_id)
      @user.update(setup: 4)

      respond_with :message, text: 'Grazie mille, ora mi serve solo sapere se lavori per EM o EM Finance', reply_markup: {
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
