require 'sidekiq'
require 'sinatra'
require 'telegram/bot'
require 'active_support'
require 'active_support/core_ext'

require_relative '../lib/app_configurator'
require_relative '../lib/message_responder'
require_relative '../lib/app_configurator'
require_relative '../models/user'
require_relative '../lib/business_date'

class RoccoWorker
  include Sidekiq::Worker
  include BusinessDate

  def perform(uid)
    user = User.find_by_uid(uid)
    logger.info "#{user.username} - #{uid} · Started for."
    user_service = Authorizer.new(user.username)
    user_projects = user_service.project_cells

    Telegram::Bot::Client.run('418922726:AAEykFkQMhJslyh6v3y68A8Wykg4sOUSa6U') do |bot|
      question = 'A cosa hai lavorato oggi?'
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: user_service.list_projects(user_projects), one_time_keyboard: true)
      bot.api.send_message(chat_id: user.uid, text: question, reply_markup: answers)
    end

    logger.info "#{user.username} - #{uid} · Message sent "

    next_business_day = next_business_day(DateTime.now)
    next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 0o0)
    user.update(jid: RoccoWorker.perform_at(next_business_day, uid), level: 3)

    logger.info "#{user.username} - #{uid} · Scheduled at #{next_business_day}"
  end
end



class CapitanRocco < Sinatra::Base
  attr_accessor :config, :logger

  configure {
    set :server, :puma
  }

  def initialize(app = nil)
    super(app)
    @config = AppConfigurator.new
    @config.configure

    @logger = @config.get_logger
    @logger.debug 'Starting telegram bot'
  end

  get '/' do
     "it works"
  end

  post '/telegram' do
    API = 'https://api.telegram.org/file/bot'.freeze
    request.body.rewind
    data = JSON.parse(request.body.read)
    @bot = Telegram::Bot::Api.new('418922726:AAEykFkQMhJslyh6v3y68A8Wykg4sOUSa6U')
    @message = Telegram::Bot::Types::Update.new(data).message

    logger.debug "@#{@message.from.username}: #{@message.text}"
    options = { bot: @bot, message: @message }

    MessageResponder.new(options).respond
    status 200
  end
end
