Rails.application.routes.draw do
  get 'user/index'

  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  telegram_webhook TelegramWebhooksController
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
