class AskJob < ApplicationJob
  include BusinessDate
  queue_as :default

  def perform(uid)
    # remove previous jobs
    ss = Sidekiq::ScheduledSet.new
    ss.select{|l| l.item["args"][0]["arguments"].include? (87171529) }.each(&:delete)

    bot = Telegram.bot
    user = User.find_by_uid(uid)
    user_service = Authorizer.new(user.uid)
    user_projects = user_service.project_cells
    project_list  = user_service.list_projects(user_projects)
    user.update(level: 3)
    bot.send_message(chat_id: uid, text: 'A cosa hai lavorato oggi?', reply_markup: {
      keyboard: project_list,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    })

    next_business_day = next_business_day(DateTime.now)
    next_business_day = DateTime.new(next_business_day.year, next_business_day.month, next_business_day.mday, 18, 0o0)
    job = AskJob.set(wait_until: next_business_day).perform_later(uid)
    user.update(jid: job.job_id, level: 3)

  end
end
