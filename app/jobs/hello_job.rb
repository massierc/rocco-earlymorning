class HelloJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    bot = Telegram.bot
    work_day = WorkDay.new(user: user, date: Date.today)
    work_day = WorkDay.find_by_date(Date.current) unless work_day.save
    sh = StateHandler.new(user: user, work_day: work_day)
    sh.public_send(work_day.aasm_state)
  end
end
