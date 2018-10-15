class AskJob < ApplicationJob
  include BusinessDate
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    return if [1,2].include?(user.company_id)
    # remove previous jobs
    ss = Sidekiq::ScheduledSet.new
    ss.select do |s|
      if s.item["args"][0].class == Hash
        s.item["args"][0]["arguments"].include? (uid)
      else
        s.item["args"][0] == uid
      end
    end.each(&:delete)

    bot = Telegram.bot
    user_service = Authorizer.new(user.uid)
    user_projects = user_service.project_cells
    project_list  = user_service.list_projects(user_projects) << ['stop']
    user.update(level: 3)
    bot.send_message(chat_id: uid, text: 'A cosa hai lavorato oggi?', reply_markup: {
      keyboard: project_list,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    })
    next_business_day = next_business_day(DateTime.current)
    job = AskJob.set(wait_until: next_business_day).perform_later(uid)
    user.update(jid: job.job_id, level: 3)
  end
end
