require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
# require "action_mailer/railtie"
require "action_view/railtie"
# require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rocco
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.telegram_updates_controller.session_store = :redis_store, {expires_in: 1.month}
    config.active_job.queue_adapter = :sidekiq
    config.i18n.locale = :it
    config.i18n.default_locale = :it
    config.time_zone = 'Rome'
    config.active_record.default_timezone = :local
  end
end

Raven.configure do |config|
  config.dsn = 'https://849ce2f806f343578377a53f6ff4564b:270e9e44e51b4ec3a32ddee9ab10887f@sentry.io/1277644' unless Rails.env.development?
end

Sidekiq::Extensions.enable_delay!
