class TelegramWebhooksController < Telegram::Bot::UpdatesController
    include Telegram::Bot::UpdatesController::MessageContext
     context_to_action!
  def start(*)
    respond_with :message, text: t('.hi')
  end

  def rename(*)
  # set context for the next message
  save_context :rename
  respond_with :message, text: 'What name do you like?'
end

# register context handlers to handle this context
context_handler :rename do |*words|
  update_name words[0]
  respond_with :message, text: 'Renamed!'
end

end
