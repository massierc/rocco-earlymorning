class User < ApplicationRecord
  has_many :work_sessions, dependent: :destroy
  has_many :work_days, dependent: :destroy

  validates :username, presence: true

  def missing_days
    updates_days = self.work_days.where(created_at: DateTime.now.beginning_of_week..DateTime.now.end_of_week).collect{|x|x.created_at.wday}
    missing = (1..5).to_a - updates_days

    if missing.empty?
      return false
    else
      "Hey, you have forgotten to update the timesheets these days: " + missing.map{|l| Date::DAYNAMES[l] }.join(", ")
    end
  end
  
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
    unless active_sessions.empty?
      active_sessions.each do |session|
        session.close
        if session.duration < 300
          session.delete_and_send_error
        else
          session.send_confirmation_message
        end
      end
    end
  end

  def find_or_create_workday
    work_day = self.work_days.find_by_date(Date.current)
    unless work_day
      work_day = self.work_days.create(date: Date.today)
    end
    work_day
  end

  def had_lunch?
    self.find_or_create_workday.work_sessions.find_by_client("Pranzo") ? true : false
  end
end
