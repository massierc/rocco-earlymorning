require 'sidekiq'
require 'sidekiq/api'

require_relative '../models/user'
require_relative '../lib/message_sender'
require_relative '../lib/authorizer'
require_relative '../bin/rocco_worker'
require_relative '../lib/business_date'




class MessageResponder
  include BusinessDate

  attr_reader :message
  attr_reader :bot
  attr_reader :user

  def initialize(options)
    @bot = options[:bot]
    @message = options[:message]
    @user = User.find_or_create_by(uid: message.from.id, username: message.from.username)
  end

  def respond
    on /^\/start/ do
      answer_with_message("Ciao #{@message[:from][:first_name]} :)")
      answer_with_message('prima di cominciare ho bisogno che mi autorizzi a modificare il tuo TimeSheet, per favore clicca su questo link')
      answer_with_message('ed in seguito digita il codice di autorizzazione')
      @url = Authorizer.new(@message[:from][:username]).get_url
      answer_with_message(@url)
      @user.update(setup: 2)
    end

    on /^(?!\/).*$/ do
      if @user.setup > 0
        handle_setup
      else
        handle_timesheet
      end
    end

    on /^\/premimimi/ do
      if @user.setup > 0
        handle_setup
      else
        Sidekiq::ScheduledSet.new.find_job(@user.jid).try(:delete)
        RoccoWorker.perform_async(@user.uid)
      end
    end

  end

  private

  def handle_timesheet
    user_service = Authorizer.new(@message[:from][:username])
    user_projects = user_service.project_cells

    if message.text =~ /stop/i
      answer_with_message("Richiesta fermata, see you #{next_business_day(DateTime.now).strftime("%A")}")
      @user.update(level: 0)
      return
    end

    case @user.level
    when 3
      @user.update(level: 2, who: message.text)

      question = 'Quale activity?'
      activities = user_service.list_activities(user_projects, @user.who)
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: [activities, "stop"], one_time_keyboard: true)
      bot.api.send_message(chat_id: @user.uid, text: question, reply_markup: answers)

    when 2
      @user.update(level: 1, what: message.text)

      question = 'E per quanto tempo?'
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: [[user.howmuch.to_s, "8"], "stop"], one_time_keyboard: true)
      bot.api.send_message(chat_id: @user.uid, text: question, reply_markup: answers)

    when 1
      @user.update(level: 0, howmuch: message.text)
      Authorizer.new(@message[:from][:username]).update_timesheet(@user)
      answer_with_message('Grazie, il tuo TimeSheet è stato aggiornato, se vuoi aggiungere altre ore di lavoro /premimimi!')
    when 0
      answer_with_message('Ma lavori ancora? :P Se vuoi aggiungere altre ore di lavoro /premimimi!')
    end
  end

  def handle_setup
    case @user.setup
    when 2
      @auth = Authorizer.new(@message[:from][:username]).store_auth(message.text)
      if @auth == 0
        answer_with_message('Codice errato, riprova per favore')
        @url = Authorizer.new(@message[:from][:username]).get_url
        answer_with_message(@url)
        @user.update(setup: 2)
      else
        answer_with_message('Grazie sei stato autenticato correttamente') if not @user.sheet_id
        answer_with_message('ora mi serve solo l\'indirizzo del tuo TimeSheet su Google Drive')
        @user.update(setup: 1)
      end
    when 1
      sheet_id = message.text.split('/').max_by(&:length)
      @user.update(sheet_id: sheet_id)
      @user.update(setup: 0)

      next_business_day = next_business_day(DateTime.now)
      next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 30)
      RoccoWorker.perform_at(next_business_day, @user.uid)
      # RoccoWorker.perform_async(@user.uid)
      answer_with_message('Grazie mille, ti contatterò alle 18:30. Vuoi segnare il tuo TimeSheet ora? /premimimi!')
    end
  end

  def on regex, &block
    regex =~ message.text

    if $~
      case block.arity
      when 0
        yield
      when 1
        yield $1
      when 2
        yield $1, $2
      end
    end
  end

  def answer_with_message(text)
    MessageSender.new(bot: bot, chat: message.chat, text: text).send
  end
end
