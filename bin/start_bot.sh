#!/bin/sh
# ruby /home/gildo/rocco/bin/bot.rb

cd /home/gildo/rocco
bundle install --path vendor/bundle
mkdir -p tmp/puma
bundle exec puma --config config/puma.rb
