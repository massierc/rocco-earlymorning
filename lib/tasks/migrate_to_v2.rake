desc "Migrate to V2"
task :migrate_to_v2 do
  include BusinessDate

  ids = ARGV.drop(1).each { |a| task a.to_sym do ; end }
  users = ids.map { |id| User.find_by_id(id.to_i) }.select { |u| u.company_id == 1 }
  users = User.where(company_id: 1) unless users.length > 0
  users.each do |u| 
    schedule_hello_job(u)
    add_workday_to_orphan_worksessions(u)
  end
end

def schedule_hello_job(u)
  next_business_day = next_business_day(DateTime.current)
  next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 9, 30)
  u.destroy_scheduled_jobs('HelloJob').set(wait_until: next_business_day).perform_later(u.uid)
end

def add_workday_to_orphan_worksessions(u)
  sessions = u.work_sessions.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
  return unless sessions.length > 0
  sessions.each do |s|
    if s.work_day.nil?
      work_day = u.find_or_create_workday
      if s.client.nil? && s.activity.nil?
        work_day.update(aasm_state: 'waiting_for_activity')
      elsif s.client.nil? && s.activity != nil
        work_day.update(aasm_state: 'waiting_for_client')
      else
        work_day.update(aasm_state: 'waiting_for_end_of_session')
      end
      s.update(work_day: work_day)
    end
  end
end
