class UpdateTimesheetsJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    date = Time.current
    user.close_active_sessions
    date_sessions = user.work_sessions.where(created_at: date.beginning_of_day..date.end_of_day)
    same_sessions = date_sessions.group_by do |ws|
      [ws.client, ws.activity]
    end
    mapped_sessions = same_sessions.map do |k,l|
      [k, rounded_hour(l.sum do |c|
        (c.duration_in_minutes)
      end)].flatten
    end
    Authorizer.new(user.uid).update_timesheet_em(user, mapped_sessions)
  end

  def rounded_hour(duration_in_minutes)
    duration_in_minutes = duration_in_minutes.round
    hours = (duration_in_minutes / 60).round
    minutes = (duration_in_minutes % 60).round

    if minutes > 44
      minutes = 0
      hours += 1
    elsif minutes < 14
      minutes = 0
    else
      minutes = 0.5
    end

    hours + minutes
  end
end
