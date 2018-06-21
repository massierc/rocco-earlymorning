class HelloJob < ApplicationJob
  include BusinessDate
  queue_as :default

  def perform(uid)
    bot = Telegram.bot
    bot.send_message(chat_id: uid, text: "Buongiorno!")
  end
end
