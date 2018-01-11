require 'rubygems'
require 'bundler/setup'

require 'sqlite3'
require 'active_record'
require 'yaml'
require 'erb'

namespace :db do
  desc 'Migrate the database'
  task :migrate do
    
    database_path = File.expand_path(File.join(File.dirname(__FILE__), './db/roccodb'))
    database_config_path = File.join(File.dirname(__FILE__), './config/database.yml')
    connection_details = YAML.safe_load(ERB.new(File.read(database_config_path)).result(binding))
    ActiveRecord::Base.establish_connection(connection_details)
    ActiveRecord::Migrator.migrate('db/migrate/')
  end
end
