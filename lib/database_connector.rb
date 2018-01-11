require 'active_record'
require 'logger'
require 'erb'

class DatabaseConnector
  class << self
    def establish_connection
      ActiveRecord::Base.logger = Logger.new(active_record_logger_path)
      configuration = YAML.safe_load(ERB.new(File.read(database_config_path)).result(binding))
      ActiveRecord::Base.establish_connection(configuration)
    end

    private

    def active_record_logger_path
      '/home/gildo/debug.log'
    end

    def database_config_path
      File.join(File.dirname(__FILE__), '../config/database.yml')
    end

    def database_path
      File.expand_path(File.join(File.dirname(__FILE__), '../db/roccodb'))
    end
  end
end
