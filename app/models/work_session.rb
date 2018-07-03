class WorkSession < ApplicationRecord
  include ActionView::Helpers::DateHelper
  belongs_to :user
  belongs_to :work_day

  after_create :start_job
  before_create :stop_previous_jobs

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

  def stop_previous_jobs
    user.work_sessions.where(end_date: nil).find_each do |ws|
      ws.stop_job
    end
  end

  def stop_job
    if self.end_date.nil?
      self.end_date = DateTime.current
      self.save
      bot = Telegram.bot

      text = "Sessione #{self.client} - #{self.activity} delle #{self.start_date.strftime("%H:%M")} chiusa dopo #{self.duration_in_words}"

      bot.send_message(chat_id: user.uid, text: text)
      user.update(level: 0)
    else
      text = "La sessione #{self.client} - #{self.activity} delle #{self.start_date.strftime("%H:%M")} era già stata chiusa alle #{self.end_date.strftime("%H:%M")}"
      bot.send_message(chat_id: user.uid, text: text)
    end
  end

  def start_job
    ss = Sidekiq::ScheduledSet.new
    ss.select do |s|
      if s.item["args"][0].class == Hash
        s.item["args"][0]["arguments"].include? (self.user.id)
      else
        s.item["args"][0] == self.user.id
      end
    end.each(&:delete)

    if lunch?
      WorkTimerJob.set(wait: 60.minutes).perform_later(user.id)
    else
      WorkTimerJob.set(wait: 30.minutes).perform_later(user.id)
    end
  end
end
