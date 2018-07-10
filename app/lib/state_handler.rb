class StateHandler
  include Utils

  def initialize(params = {})
    @user = params[:user]
    @work_day = params[:work_day]
    @bot = Telegram.bot
  end

  def waiting_for_morning
    @work_day.wait_for_activity!
    @bot.send_message(chat_id: @user.uid, text: "Da dove lavori oggi?", reply_markup: {
      inline_keyboard: [
        [{text: 'Ufficio', callback_data: cb_data(@work_day.aasm_state, 'Ufficio')}],
        [{text: 'Remoto', callback_data: cb_data(@work_day.aasm_state, 'Remoto')}],
        [{text: 'Cliente', callback_data: cb_data(@work_day.aasm_state, 'Cliente')}]
      ]
    })
  end
  
  def waiting_for_activity
    @work_day.wait_for_client!
    project_list = Authorizer.new(@user.uid).list_projects(Authorizer.new(@user.uid).project_cells)
    keyboard = []
    project_list.each do |p|
      keyboard_row = p.map { |proj| { text: proj, callback_data: cb_data(@work_day.aasm_state, proj) } }  
      keyboard << keyboard_row
    end
    btn_add_new_proj = [{ text: '+ aggiungi', callback_data: cb_data(@work_day.aasm_state, 'new_proj') }]
    keyboard << btn_add_new_proj
    @bot.send_message(
      chat_id: @user.uid, 
      text: 'A cosa stai lavorando?', 
      reply_markup: { inline_keyboard: keyboard }
    )
  end

  def waiting_for_client
    @work_day.wait_for_end_of_session!
    @bot.send_message(
      chat_id: @user.uid, 
      text: "Scrivimi quando finisci, mi farò comunque vivo tra mezz'ora per assicurarmi che non ti scordi di me 😃"
    )
    @user.destroy_scheduled_jobs('WorkTimerJob').set(wait: 30.minutes).perform_later(@user.id)
  end

  def waiting_for_end_of_session
    @work_day.end_session!
    @bot.send_message(
      chat_id: @user.uid, 
      text: "Vuoi aggiungere una nuova attività?", 
      reply_markup: { 
        inline_keyboard: [
          [
            { text: 'Sì', callback_data: cb_data(@work_day.aasm_state, 'add_new_activity') },
            { text: 'No', callback_data: cb_data(@work_day.aasm_state, 'good_night') }
          ]
        ]
      }
    )
  end

  def waiting_for_user_input
    waiting_for_morning
  end
end