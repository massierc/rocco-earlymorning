#!/bin/sh
bundle exec sidekiq -r /home/gildo/rocco/bin/bot.rb -C /home/gildo/rocco/config/sidekiq.yml
