require 'sidekiq/web'

Rails.application.routes.draw do
  get 'user/index'

  mount Sidekiq::Web => '/sidekiq'
  telegram_webhook TelegramWebhooksController
end
