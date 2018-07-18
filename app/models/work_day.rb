class WorkDay < ApplicationRecord
  include AASM
  include Utils

  I18n.locale = :it

  belongs_to :user
  has_many :work_sessions, dependent: :destroy

  validates :date, uniqueness: { scope: :user }

  aasm do
    state :waiting_for_morning, initial: true
    state :waiting_for_activity,
          :waiting_for_client,
          :waiting_for_new_client,
          :waiting_for_end_of_session,
          :waiting_for_user_input,
          :waiting_for_confirmation,
          :workday_finished
          
    event :wait_for_activity do
      transitions from: [:waiting_for_morning, :waiting_for_user_input, :waiting_for_client], to: :waiting_for_activity
    end

    event :wait_for_client do
      transitions from: [:waiting_for_activity, :waiting_for_new_client], to: :waiting_for_client
    end

    event :wait_for_new_client do
      transitions from: :waiting_for_client, to: :waiting_for_new_client
    end

    event :wait_for_end_of_session do
      transitions from: [:waiting_for_client, :waiting_for_confirmation], to: :waiting_for_end_of_session
    end

    event :wait_for_user_input do
      transitions from: :waiting_for_end_of_session, to: :waiting_for_user_input
    end

    event :wait_for_confirmation do
      transitions from: :waiting_for_user_input, to: :waiting_for_confirmation
    end

    event :wait_for_morning do
      transitions from: :waiting_for_user_input, to: :waiting_for_morning
    end

    event :end do
      transitions from: :waiting_for_confirmation, to: :workday_finished
    end
  end

  def send_evening_recap
    return unless self.work_sessions.length > 0
    line_length = 28
    if self.user.name
      first_name = self.user.name.split.map(&:capitalize)[0]
      date = I18n.localize(self.date, format: "%d %b %Y").rjust(line_length - first_name.length)
    else
      first_name = ""
      date = I18n.localize(self.date, format: "%d %b %Y").rjust(line_length)
    end
    opening_tag = "<pre>"
    closing_tag = "</pre>"
    new_line = "\n"
    header = first_name + date + new_line
    rows = ""
    total = 0
    self.work_sessions.each_with_index do |ws, i|
      next if ws.client.nil?
      total += ws.duration
      index = "#{i + 1}) "
      rows += index + "Attività:  " + ws.activity.rjust(14) + new_line
      rows += "   Cliente:   " + ws.client.rjust(14) + new_line
      rows += "   Durata:    " + duration_in_hours_and_minutes(ws.duration).rjust(14) + new_line
      rows += new_line unless i == work_sessions.length - 1
    end
    line = "_" * line_length
    total = "TOTALE #{duration_in_hours_and_minutes(total).rjust(21)}"
    message = opening_tag \
            + header \
            + line \
            + new_line \
            + new_line \
            + rows \
            + line \
            + new_line \
            + total \
            + new_line \
            + closing_tag
    Telegram.bot.send_message(chat_id: self.user.uid, text: "Ecco il tuo recap giornaliero 👇")
    Telegram.bot.send_message(chat_id: self.user.uid, text: "#{message}", parse_mode: :HTML)    
  end
end
