require 'telegram/bot'
require 'logger'

require_relative '../lib/database_connector'
require_relative '../lib/message_responder'

class AppConfigurator
  def configure
    setup_i18n
    setup_database
  end

  def get_token
    secrets = File.join(File.dirname(__FILE__), "../config/secrets.yml")
    YAML::load(IO.read(secrets))['telegram_bot_token']
  end

  def get_logger
    Logger.new(STDOUT, Logger::DEBUG)
  end

  private

  def setup_i18n
    locales = File.join(File.dirname(__FILE__), '../config/locales.yml')
    I18n.load_path = Dir[locales]
    I18n.locale = :it
    I18n.backend.load_translations
  end

  def setup_database
    DatabaseConnector.establish_connection
  end
end

class Numeric
  Alpha26 = ("a".."z").to_a
  def to_s26
    return "" if self < 1
    s, q = "", self
    loop do
      q, r = (q - 1).divmod(26)
      s.prepend(Alpha26[r])
      break if q.zero?
    end
    s
  end
end
