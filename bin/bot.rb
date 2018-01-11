#!/usr/bin/env ruby
require_relative '../lib/app_configurator'
require_relative '../lib/message_responder'

config = AppConfigurator.new
config.configure

token = config.get_token
logger = config.get_logger
logger.debug 'Starting telegram bot'

require 'sidekiq'
require 'telegram/bot'
require 'active_support'
require 'active_support/core_ext'

require_relative '../lib/app_configurator'
require_relative '../models/user'
require_relative '../lib/business_date'


class RoccoWorker
  include Sidekiq::Worker
  include BusinessDate

  def perform(uid)
    config = AppConfigurator.new
    config.configure
    token = config.get_token

    user = User.find_by_uid(uid)

    user_service = Authorizer.new(user.username)
    user_projects = user_service.project_cells

    Telegram::Bot::Client.run(token) do |bot|
      question = 'A cosa hai lavorato oggi?'
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup
        .new(keyboard: user_service.list_projects(user_projects), one_time_keyboard: true)
      bot.api.send_message(chat_id: user.uid, text: question, reply_markup: answers)
    end


    # workdays = user_service.workday_cells
    # next_workday = user_service.find_next_workday(workdays).to_i
    #
    # if next_workday
    #   next_workday = datetime.change(day: next_workday, hour: 18, min: 30)
    # else
    next_business_day = next_business_day(DateTime.now)
    next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 00)
    # end

    user.update(jid: RoccoWorker.perform_at(next_business_day, uid), level: 3)
  end
end

if ARGV[0] == "bot"
  Telegram::Bot::Client.run(token) do |bot|
    bot.listen do |message|
      options = {bot: bot, message: message}

      logger.debug "@#{message.from.username}: #{message.text}"  if defined? message.text
      MessageResponder.new(options).respond
    end
  end
end
