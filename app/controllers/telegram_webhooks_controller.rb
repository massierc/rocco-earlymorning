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
    send_error_message unless @user.save
  end

  def message(_message)
    return unless @user.persisted?
    return unless @user.company_id == 0 || debugging_with('ElenorGee', 'marinamo', 'massierc')
    @user.setup > 0 ? handle_setup : handle_timesheet
  end

  def callback_query(data)
    data = JSON.parse(data)
    respond_with :message, text: "Ciao #{@message['from']['username']}!"
  end

  def premimimi
    @user.setup > 0 ? handle_setup : @user.destroy_scheduled_jobs('AskJob').perform_later(@user.uid)
  end

  def nwo(*args)
    admins = %w[gildof massierc riccardocattaneo17 GiudiEM]
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
      respond_with_error_message('nwo')
    end
  end

  def unbillable
    admins = %w[gildof riccardocattaneo17 GiudiEM]
    if admins.include? @message['from']['username']
      UnbillableJob.perform_later
      respond_with :message, text: "Ciao #{@message['from']['username']}, job Unbillable avviato con successo 👍"
    else
      respond_with_error_message('unbillable')
    end
  end

  def pigri
    admins = %w[gildof riccardocattaneo17 massierc]
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
      respond_with_error_message('pigri')
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

  def send_error_message
    attribute = @user.errors.messages.first[0].to_s.capitalize
    error = @user.errors.messages.first[1][0]
    @bot.send_message(chat_id: @user.uid, text: "❌ #{attribute} #{error}")
  end

  def debugging_with(*users)
    if users.include? @message['from']['username']
      true
    else
      respond_with :message, text: "Scusa, sono in manutenzione. Tornerò presto 🍆"
      false
    end
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
      if @user.company_id == 0
        @user.update(level: 1, what: @message['text'])
      else  
        @user.update(level: 1, who: @message['text'])
        @user.update(level: 1, what: nil)
      end
      respond_with :message, text: 'E per quanto tempo?', reply_markup: {
        keyboard: [%w[0.5 1 2 3], %w[4 5 6 7], %w[8 stop]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    when 1
      @user.update(level: 0, howmuch: @message['text'])
      Authorizer.new(@user.uid).update_timesheet
      msg = "Grazie, il tuo TimeSheet è stato aggiornato!\nPremi /nota per aggiungere un commento.\nSe vuoi aggiungere altre ore di lavoro /premimimi!"
      if @user.special
        handle_special_user
      else
        respond_with :message, text: msg
      end
    when 0
      respond_with :message, text: 'Ma lavori ancora? 🤓 Se vuoi aggiungere altre ore di lavoro /premimimi!'
    end
  end

  def handle_setup
    case @user.setup
    when 4
      if %w[EM EMF].include? @message['text'].upcase.chomp
        @message['text'] == 'EM' ? @user.update(company_id: 1, setup: 0) : @user.update(company_id: 0, setup: 0)
        respond_with :message, text: 'Grazie mille, il setup è completo!'
        respond_with :message, text: 'Ti contatterò alle 19:00. Vuoi segnare il tuo TimeSheet ora? /premimimi!'
        contact_time = current_or_next_business_day(DateTime.current)
        job = @user.destroy_scheduled_jobs('AskJob').set(wait_until: contact_time).perform_later(@user.uid)
        @user.update(level: 3)
      else
        respond_with :message, text: 'Scusa non ho capito, sei EM o EM Finance (EM/EMF)?', reply_markup: {
          keyboard: [%w[EM EMF]],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
        }
      end
    when 3
      start
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
      @user.update(sheet_id: sheet_id, setup: 4)
      respond_with :message, text: 'Grazie mille, ora mi serve sapere se lavori per EM o EM Finance', reply_markup: {
        keyboard: [%w[EM EMF]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    end
  end

  def handle_special_user
    random_rocco = Dir[Rails.root.join('public', 'rocco', '*')].sample
    if random_rocco.include?('gif')
      respond_with :document, document: File.open(random_rocco), caption: msg
    else
      respond_with :photo, photo: File.open(random_rocco), caption: msg
    end
  end

  def respond_with_error_message(command)
    respond_with :message, text: "#{@message['from']['username']} /#{command} è un comando riservato, non sei admin."
    respond_with :message, text: "L'incidente verrà riportato."
    sleep(5)
    respond_with :message, text: '..scherzooo!'
  end
end
