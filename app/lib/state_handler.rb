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
    project_list = Authorizer.new(@user.uid).list_projects(Authorizer.new(@user.uid).project_cells)
    return unless project_list
    @work_day.wait_for_client!
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
    work_session = @work_day.work_sessions.last
    if @user.company_id == 1
      @bot.send_message(
        chat_id: @user.uid, 
        text: "Scrivimi quando finisci, mi rifarò vivo tra mezz'ora 😃"
      )
    elsif @user.company_id == 2
      @bot.send_message(
        chat_id: @user.uid, 
        text: "Scrivimi quando finisci 😃"
      )
    end
    wait_time = work_session.calculate_wait_time(@user)
    @user.destroy_scheduled_jobs('WorkTimerJob').set(wait_until: wait_time).perform_later(@user.id)
  end

  def waiting_for_end_of_session
    @work_day.wait_for_user_input!
    @bot.send_message(
      chat_id: @user.uid, 
      text: "Vuoi aggiungere una nuova attività?", 
      reply_markup: { 
        inline_keyboard: [
          [
            { text: 'Sì', callback_data: cb_data(@work_day.aasm_state, 'add_new_activity') },
            { text: 'No', callback_data: cb_data(@work_day.aasm_state, 'ask_confirmation') }
          ]
        ]
      }
    )
  end

  def waiting_for_user_input
    @work_day.wait_for_confirmation!
    @bot.send_message(
      chat_id: @user.uid, 
      text: "❗️ Sei sicuro? Se confermi aggiornerò il tuo timesheet e non potrai aggiungere attività per oggi ❗️", 
      reply_markup: { 
        inline_keyboard: [
          [
            { text: 'Sì, chiudi e aggiorna 👍', callback_data: cb_data(@work_day.aasm_state, 'good_night') },
            { text: 'No, aspetta 🖐', callback_data: cb_data(@work_day.aasm_state, 'ask_again') }
          ]
        ]
      }
    )
  end
end