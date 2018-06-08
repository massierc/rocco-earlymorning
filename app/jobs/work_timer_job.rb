class WorkTimerJob < ApplicationJob
  include BusinessDate
  queue_as :default

  def perform(user_id)
    bot = Telegram.bot
    user = User.find(user_id)
    ws = user.active_worksession

    if ws
      if ws.client == "Pranzo"
        timer_text = "Sei ancora a pranzo?"
      else
        timer_text = "Stai ancora lavorando a #{ws.client}-#{ws.activity} ?"
      end
    
      timer_options = [
        {text: "Sì", callback_data: 'yes'},
        {text: "No", callback_data: 'no'},
        {text: "Bye", callback_data: 'bye'},
      ]

      start_lunch = Time.now.change(hour: 12, min: 25)
      end_lunch = Time.now.change(hour: 14, min: 15)

      puts Time.now
      if Time.now.between?(start_lunch, end_lunch) && !ws.lunch?
        puts "SISISI"
        timer_text += " o sei a PRANZO?"
        timer_options.unshift({text: "PRANZO", callback_data: 'lunch'})
      end

      bot.send_message(chat_id: user.uid, text: timer_text, reply_markup: {
        inline_keyboard: [
          timer_options
        ],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      })

      job = WorkTimerJob.set(wait: 30.minutes).perform_later(user.id)
      # user.update(jid: job.job_id, level: 3)
    else
      puts "no WS active"
    end
  end

end
