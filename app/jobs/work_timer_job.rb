# frozen_string_literal: true

class WorkTimerJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    I18n.locale = :it
    bot = Telegram.bot
    ws = user.active_worksession

    if ws
      work_day = ws.work_day
      timer_text = ask_for_updates(ws)
      timer_options = [
        [{text: 'Sto ancora lavorando 🤓', callback_data: cb_data(work_day.aasm_state, 'still_working')}],
        [{text: 'No, ho finito 👍', callback_data: cb_data(work_day.aasm_state, 'finished')}]
      ]

      start_lunch = ws.start_lunch
      end_lunch = ws.end_lunch

      if Time.current.between?(start_lunch, end_lunch) && !ws.lunch?
        timer_text.chomp!('?')
        timer_text += ' o sei a pranzo?'
        timer_options.push([{text: 'Sono a pranzo! 🍝', callback_data: cb_data(work_day.aasm_state, 'lunch')}])
      elsif ws.lunch?
        timer_options = [
          [
            {text: 'Sì', callback_data: cb_data(work_day.aasm_state, 'still_working')},
            {text: 'No, ho finito 👍', callback_data: cb_data(work_day.aasm_state, 'finished')}
          ]
        ]
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

      wait_time = work_session.calculate_wait_time(user)
      user.destroy_scheduled_jobs('WorkTimerJob').set(wait_until: wait_time).perform_later(user.id)
    else
      work_day = user.find_or_create_workday
      sh = StateHandler.new(user: user, work_day: work_day)
      bot.send_message(chat_id: user.uid, text: 'Non trovo attività aperte')
      sh.public_send(work_day.aasm_state)
    end
  end

  def ask_for_updates(ws)
    if ws.client == 'Pranzo'
      text = 'Sei ancora a pranzo?'
    else
      text = "Stai ancora lavorando per #{ws.client} "
      case ws.activity
      when 'Ufficio'
        text += 'in ufficio?'
      when 'Cliente'
        text += 'dal cliente?'
      when 'Remoto'
        text += 'da remoto?'
      end
    end
    text
  end
end
