class StateHandler
  include Utils

  def initialize(params = {})
    @user = params[:user]
    @message_id = params[:message_id]
    @work_day = params[:work_day]
    @bot = Telegram.bot
  end

  def waiting_for_morning
    @work_day.good_morning!
    @bot.send_message(chat_id: @user.uid, text: "Buongiorno! Da dove lavori oggi?", reply_markup: {
      inline_keyboard: [
        [
          {text: 'Ufficio', callback_data: cb_data(@work_day.aasm_state, 'ufficio')}
        ],
        [
          {text: 'Remoto', callback_data: cb_data(@work_day.aasm_state, 'remoto')},
          {text: 'Cliente', callback_data: cb_data(@work_day.aasm_state, 'cliente')}
        ]
      ]
    })
  end
  
  def waiting_for_activity
    @work_day.get_activity!
    project_list = Authorizer.new(@user.uid).list_projects(Authorizer.new(@user.uid).project_cells)
    keyboard = []
    project_list.each do |p|
      keyboard_row = p.map { |proj| { text: proj, callback_data: cb_data(@work_day.aasm_state, proj) } }  
      keyboard << keyboard_row
    end 
    @bot.edit_message_text({
      text: 'A cosa stai lavorando?', 
      chat_id: @user.uid, 
      message_id: @message_id, 
      reply_markup: { inline_keyboard: keyboard }
    })
  end

  def waiting_for_client
    @work_day.get_client!
    @bot.edit_message_text({
      text: "Scrivimi quando finisci, mi farò comunque vivo tra mezz'ora per assicurarmi che non ti scordi di me 😃", 
      chat_id: @user.uid, 
      message_id: @message_id, 
      reply_markup: { inline_keyboard: [] }
    })
    answer_callback_query 'Timer avviato ⏲️'
  end
end