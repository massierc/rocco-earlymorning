class HelloJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    user.destroy_scheduled_jobs('HelloJob')
    bot = Telegram.bot
    unless user.work_days.find_by_date(Date.current)
      bot.send_message(chat_id: user.uid, text: 'Buongiorno! ☀️')
    end
    work_day = user.find_or_create_workday
    sh = StateHandler.new(user: user, work_day: work_day)
    sh.public_send(work_day.aasm_state)
  end
end
