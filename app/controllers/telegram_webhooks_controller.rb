class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  include BusinessDate
  context_to_action!

  before_action :set_user

  def set_user
    @message = ActiveSupport::HashWithIndifferentAccess.new(payload)
    @user = User.find_or_create_by(uid: @message['from']['id'], username: @message['from']['username'])
  end

  def premimimi
    if @user.setup > 0
      handle_setup
    else
      AskJob.perform_later(@user.uid)
    end
  end

  def message(_message)
    if @user.setup > 0
      handle_setup
    else
      handle_timesheet
    end
  end

  def start(*)
    respond_with :message, text: "Ciao #{@message[:from][:first_name]} :)"
    respond_with :message, text: 'prima di cominciare ho bisogno che mi autorizzi a modificare il tuo TimeSheet, per favore clicca su questo link'
    respond_with :message, text: 'ed in seguito digita il codice di autorizzazione'
    @url = Authorizer.new(@message[:from][:username]).get_url
    respond_with :message, text: @url
    @user.update(setup: 2)
  end

  private

  def handle_timesheet
    user_service = Authorizer.new(@message[:from][:id])
    user_projects = user_service.project_cells

    if @message["text"] =~ /stop/i
      respond_with :message, text: "Richiesta fermata, see you #{next_business_day(DateTime.now).strftime("%A")}"
      @user.update(level: 0)
      return
    end

    case @user.level
    when 3
      @user.update(level: 2, who: @message["text"])

      activities = user_service.list_activities(user_projects, @user.who)
      respond_with :message, text: "Quale activity?", reply_markup: {
        keyboard: [activities],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true,
      }

    when 2
      @user.update(level: 1, what: @message["text"])

      activities = user_service.list_activities(user_projects, @user.who)
      respond_with :message, text: 'E per quanto tempo?', reply_markup: {
        keyboard: [[@user.howmuch.to_s, "8"], ["stop"]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true,
      }

    when 1
      @user.update(level: 0, howmuch: @message["text"])
      Authorizer.new(@message[:from][:id]).update_timesheet(@user)
      respond_with :message, text: 'Grazie, il tuo TimeSheet è stato aggiornato, se vuoi aggiungere altre ore di lavoro /premimimi!'
    when 0
      respond_with :message, text: 'Ma lavori ancora? :P Se vuoi aggiungere altre ore di lavoro /premimimi!'
    end
  end


  def handle_setup
    case @user.setup
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
      @user.update(setup: 0)

      next_business_day = next_business_day(DateTime.now)
      next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 30)
      respond_with :message, text: 'Grazie mille, ti contatterò alle 18:30. Vuoi segnare il tuo TimeSheet ora? /premimimi!'
    end
 end
end