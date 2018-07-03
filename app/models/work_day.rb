class WorkDay < ApplicationRecord
  include AASM
  belongs_to :user
  has_many :work_sessions

  aasm do
    state :waiting_for_morning, initial: true
    state :waiting_for_activity,
          :waiting_for_client,
          :waiting_for_end_of_session
          
    event :good_morning do
      transitions from: :waiting_for_morning, to: :waiting_for_activity
    end

    event :get_activity do
      transitions from: :waiting_for_activity, to: :waiting_for_client
    end

    event :get_client do
      transitions from: :waiting_for_client, to: :waiting_for_end_of_session
    end

    event :end_session do
      transitions from: :waiting_for_end_of_session, to: :waiting_for_client
    end

    event :good_night do
      transitions from: :waiting_for_client, to: :waiting_for_morning
    end
  end
end
