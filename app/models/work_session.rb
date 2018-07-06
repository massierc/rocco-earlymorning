class WorkSession < ApplicationRecord
  include ActionView::Helpers::DateHelper
  include Utils
  belongs_to :user
  belongs_to :work_day

  after_create :start_job
  before_create :close_active_sessions

  I18n.locale = :it

  def duration
    (end_date - start_date)
  end

  def duration_in_minutes
    duration / 1.minutes
  end

  def duration_in_hours
    duration_in_minutes / 60
  end

  def duration_in_words
    distance_of_time_in_words(start_date, end_date, include_seconds: true)
  end

  def lunch?
    self.client == "Pranzo"
  end

  def close_active_sessions
    self.user.close_active_sessions
  end

  def close
    if self.end_date.nil?
      self.update(end_date: DateTime.current)
    end
  end

  def close_and_send_confirmation
    if self.end_date.nil?
      self.close
      self.send_confirmation_message
    end
  end
  
  def start_job
    user = self.user
    job = user.destroy_scheduled_jobs('WorkTimerJob')
    if lunch?
      job.set(wait: 60.minutes).perform_later(user.id)
    else
      job.set(wait: 30.minutes).perform_later(user.id)
    end
  end
  
  def send_confirmation_message
    bot = Telegram.bot
    self.client.nil? ? client = '' : client = " per #{self.client}"
    case self.activity
    when 'Ufficio'
      activity = ' in ufficio'
    when 'Cliente'
      activity = ' dal cliente'
    when 'Remoto'
      activity = ' da remoto'
    when nil
      activity = ''
    end
    text = "▶️ la sessione#{activity + client} delle #{self.start_date.strftime("%H:%M")} è stata chiusa dopo #{self.duration_in_words}"
    bot.send_message(chat_id: user.uid, text: text)
  end
end
