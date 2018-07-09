class User < ApplicationRecord
  has_many :work_sessions
  has_many :work_days

  def active_worksession
    self.work_sessions.find_by_end_date(nil)
  end

  def destroy_scheduled_jobs(job_name)
    user = self
    ids = [user.id, user.uid]
    ss = Sidekiq::ScheduledSet.new
    ss.select do |s|
      job = s.item['wrapped']
      arg = s.item['args'][0]
      if arg.class == Hash
        condition = arg['arguments'].all? { |i| ids.include? i }
      else
        condition = arg == user.id || user.uid
      end
      condition && job == job_name
    end.each(&:delete)
    job = Object.const_get job_name
  end

  def close_active_sessions
    active_sessions = self.work_sessions.where(end_date: nil)
    active_sessions.each { |session| session.close_and_send_confirmation } unless active_sessions.empty?
  end

  def find_or_create_workday
    work_day = self.work_days.find_by_date(Date.current)
    unless work_day
      work_day = self.work_days.create(date: Date.today)
    end
    work_day
  end
end
