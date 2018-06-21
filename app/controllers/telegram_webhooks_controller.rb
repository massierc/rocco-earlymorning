class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  include BusinessDate
  context_to_action!

  before_action :set_user

  def set_user
    @message = ActiveSupport::HashWithIndifferentAccess.new(payload)
    @user = User.find_or_initialize_by(uid: @message['from']['id'], username: @message['from']['username'])
    @user.setup = 3 unless @user.persisted?
    @user.save
  end

  def callback_query(data)
    def manage_timer(data)
      case data
      when 'yes'
        respond_with :message, text: 'Buon lavoro ;) '
      when 'no'
        end_worksession
      when 'lunch'
        end_worksession(lunch = true)
        create_lunch
      when 'bye'
        end_worksession(bye = true)
        respond_with :message, text: 'OK, tra poco aggiorno il tuo TimeSheet, buona giornata!'
        @user.delay.update_timesheets
        next_business_day = next_business_day(DateTime.current)
        next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 9, 30)
        job = HelloJob.set(wait_until: next_business_day).perform_later(@user.uid)
      end
    end
    manage_timer(data)
    answer_callback_query 'OK'
  end

  def premimimi
    if @user.setup > 0
      handle_setup
    else
      AskJob.perform_later(@user.uid)
    end
  end

  def nwo
    admins = %w[gildof riccardocattaneo17]
    if admins.include? @message['from']['username']
      RiccardoJob.perform_later
      respond_with :message, text: "Ciao #{@message['from']['username']}, job NWO avviato con successo 💩"
    else
      respond_with :message, text: "#{@message['from']['username']} /nwo è un comando riservato, non sei admin."
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
        handle_worksession
      end
    end
  end

  def start(*)
    respond_with :message, text: "Ciao #{@message[:from][:first_name]} :)"
    respond_with :message, text: 'prima di cominciare ho bisogno che mi autorizzi a modificare il tuo TimeSheet, per favore clicca su questo link'
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

  def end_worksession(bye = false)
    @ws = @user.active_worksession
    if @ws.nil? && bye == false
      respond_with :message, text: 'Nessuna sessione attiva'
    elsif bye
      @ws.stop_job if @ws
      return
    else
      @ws.stop_job
      unless bye
        @message['text'] = 'Hellooooooooo!'
        handle_worksession
      end
    end
  end

  def create_lunch
    @user.work_sessions.create(start_date: DateTime.current, client: 'Pranzo', activity: '')
    m = 'Timer avviato, buon pranzo!'
    respond_with :message, text: m
  end

  def handle_worksession
    # TODO: If active worksession don't do nothing
    if @message['text'] =~ /stop/i
      end_worksession
      return
    end

    user_service = Authorizer.new(@message[:from][:id])
    user_projects = user_service.project_cells
    project_list  = user_service.list_projects(user_projects)

    case @user.level
    when 4
      if @user.active_worksession.nil?
        @user.update(level: 0)
        handle_worksession
      end
      WorkTimerJob.new.perform(@user.id)
    when 3
      respond_with :message, text: 'A cosa stai lavorando?', reply_markup: {
        keyboard: project_list,
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
      @user.update(level: 2, what: @message['text'])

    when 0
      @user.update(level: 3)

      respond_with :message, text: 'Da dove lavori oggi?', reply_markup: {
        keyboard: [%w[Remoto Ufficio Cliente]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    when 2
      @user.update(level: 4, who: @message['text'])
      # Authorizer.new(@message[:from][:id]).update_timesheet(@user)
      @user.work_sessions.create(start_date: DateTime.current, client: @user.who, activity: @user.what)
      m = 'Timer avviato, buon lavoro!'
      respond_with :message, text: m
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
          respond_with :message, text: 'Grazie mille, ti contatterò alle 18:00. Vuoi segnare il tuo TimeSheet ora? /premimimi!'
        end

        if @user.company_id == 0
          next_business_day = next_business_day(DateTime.current)
          next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 0o0)
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
