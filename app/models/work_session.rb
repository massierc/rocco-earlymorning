class WorkSession < ApplicationRecord
  include ActionView::Helpers::DateHelper
  belongs_to :user

  after_create :start_job

  I18n.locale = :it
  
  def duration
    end_date - start_date
  end

  def duration_in_words
    distance_of_time_in_words(start_date, end_date, include_seconds: true)
  end

  def start_job
    WorkTimerJob.set(wait: 30.minutes).perform_later(user.id)
  end
end
