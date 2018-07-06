desc "Migrate to V2"
task :migrate_to_v2 do
  include BusinessDate
  User.where(company_id: 1).each do |u|
    # Schedule HelloJob for the next business day
    next_business_day = next_business_day(DateTime.current)
    next_business_day = Time.new(next_business_day.year, next_business_day.month, next_business_day.mday, 9, 30)
    @user.destroy_scheduled_jobs('HelloJob').set(wait_until: next_business_day).perform_later(@user.uid)

    # Give today's orphan WorkSessions a WorkDay
    sessions = u.work_sessions.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
    next unless sessions.length > 0
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
end