class AskJob < ApplicationJob
  include BusinessDate
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    bot = Telegram.bot
    user_service = Authorizer.new(user.uid)
    user_projects = user_service.project_cells
    project_list  = user_service.list_projects(user_projects) << ['stop']
    user.company_id == 0 ? user.update(level: 3) : user.update(level: 2)
    bot.send_message(chat_id: uid, text: 'A cosa hai lavorato oggi?', reply_markup: {
      keyboard: project_list,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    })
    job = AskJob.set(wait_until: next_business_day(DateTime.current)).perform_later(uid)
  end
end
