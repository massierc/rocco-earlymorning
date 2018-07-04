class HelloJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    bot = Telegram.bot
    work_day = WorkDay.find_by_date(Date.current)
    unless work_day
      work_day = WorkDay.create(user: user, date: Date.today)
      bot.send_message(chat_id: user.uid, text: 'Buongiorno! ☀️')
    end
    sh = StateHandler.new(user: user, work_day: work_day)
    sh.public_send(work_day.aasm_state)
  end
end
