class WorkSession < ApplicationRecord
  include ActionView::Helpers::DateHelper
  belongs_to :user

  I18n.locale = :it
  
  def duration
    end_date - start_date
  end

  def duration_in_words
    distance_of_time_in_words(start_date, end_date, include_seconds: true)
  end
end
