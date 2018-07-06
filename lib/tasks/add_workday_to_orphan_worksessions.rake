desc "Give today's orphan WorkSessions a WorkDay"
task :add_workday_to_orphan_worksessions do
  User.all.each do |u|
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