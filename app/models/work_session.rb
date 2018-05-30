class WorkSession < ApplicationRecord
  include ActionView::Helpers::DateHelper
  belongs_to :user

  after_create :start_job
  before_create :stop_previous_jobs

  I18n.locale = :it
  
  def duration
    end_date - start_date
  end

  def duration_in_words
    distance_of_time_in_words(start_date, end_date, include_seconds: true)
  end

  def lunch?
    self.client == "Pranzo"
  end

  def stop_previous_jobs
    user.work_sheets.where(date_end: nil).find_each do |wa|
      ws.stop_job
    end
  end

  def stop_job
    self.end_job = DateTime.now
    self.save
  end

  def start_job
    if lunch?
      WorkTimerJob.set(wait: 60.minutes).perform_later(user.id)
    else
      WorkTimerJob.set(wait: 30.minutes).perform_later(user.id)
    end
  end
end
