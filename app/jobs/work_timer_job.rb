# frozen_string_literal: true

class WorkTimerJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    I18n.locale = :it

    ss = Sidekiq::ScheduledSet.new
    ss.select do |s|
      if s.item['args'][0].class == Hash
        s.item['args'][0]['arguments'].include? user.id
      else
        s.item['args'][0] == user.id
      end
    end.each(&:delete)

    bot = Telegram.bot
    ws = user.active_worksession
    work_day = ws.work_day

    if ws
      timer_text = ask_for_updates(ws)

      timer_options = [
        [
          {text: 'Sto ancora lavorando 🤓', callback_data: cb_data(work_day.aasm_state, 'still_working')}
        ],
        [
          {text: 'No, ho finito 👍', callback_data: cb_data(work_day.aasm_state, 'finished')}
        ]
      ]

      start_lunch = Time.current.change(hour: 12, min: 25)
      end_lunch = Time.current.change(hour: 21, min: 15)
      # end_lunch = Time.current.change(hour: 14, min: 15) TODOOOOOOOOOO <---------------------------------------------------------------------------

      puts Time.current
      if Time.current.between?(start_lunch, end_lunch) && !ws.lunch?
        timer_text.chomp!('?')
        timer_text += ' o sei a pranzo?'
        timer_options.push([{text: 'Sono a pranzo! 🍝', callback_data: cb_data(work_day.aasm_state, 'lunch')}])
      end

      bot.send_message(
        chat_id: user.uid,
        text: timer_text,
        reply_markup: {
          inline_keyboard: timer_options,
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
        }
      )

      job = WorkTimerJob.set(wait: 30.minutes).perform_later(user.id)
    else
      puts 'no active WS'
    end
  end

  def ask_for_updates(ws)
    if ws.client == 'Pranzo'
      text = 'Sei ancora a pranzo?'
    else
      text = "Stai ancora lavorando per #{ws.client} "
      case ws.activity
      when 'ufficio'
        text += 'in ufficio?'
      when 'cliente'
        text += 'dal cliente?'
      when 'remoto'
        text += 'da remoto?'
      end
    end
    text
  end
end
