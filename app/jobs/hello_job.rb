class HelloJob < ApplicationJob
  include BusinessDate
  include Utils
  queue_as :default

  def perform(uid)
    user = User.find_by_uid(uid)
    bot = Telegram.bot
    session = WorkDay.new
    session.user = user
    session.good_morning!
    bot.send_message(chat_id: uid, text: "Buongiorno! Da dove lavori oggi?", reply_markup: {
      inline_keyboard: [
        [
          {text: 'Ufficio', callback_data: cb_data(session.aasm_state, 'ufficio')}
        ],
        [
          {text: 'Remoto', callback_data: cb_data(session.aasm_state, 'remoto')},
          {text: 'Cliente', callback_data: cb_data(session.aasm_state, 'cliente')}
        ]
      ]
    })
  end
end
