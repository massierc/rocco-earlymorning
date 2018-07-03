class HelloJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    bot = Telegram.bot
    work_day = WorkDay.new(user: user, date: Date.today)
    work_day.save ? work_day.good_morning! : work_day = WorkDay.find_by_date(Date.current)
    bot.send_message(chat_id: uid, text: "Buongiorno! Da dove lavori oggi?", reply_markup: {
      inline_keyboard: [
        [
          {text: 'Ufficio', callback_data: cb_data(work_day.aasm_state, 'ufficio')}
        ],
        [
          {text: 'Remoto', callback_data: cb_data(work_day.aasm_state, 'remoto')},
          {text: 'Cliente', callback_data: cb_data(work_day.aasm_state, 'cliente')}
        ]
      ]
    })
  end
end
