# frozen_string_literal: true

class UnbillableJob < ApplicationJob
  queue_as :default
  include Utils

  def perform
    I18n.locale = :it
    dates = []
    current_month = Date.today
    dates << current_month

    until current_month.month == 10
      current_month += 1.month
      dates << current_month
    end

    bot = Telegram.bot
    bot.send_message(chat_id: riccardo_uid, text: 'Unbillable lanciato per: ' +
       dates.collect { |d| I18n.l(d, format: '%B').capitalize }.join(', '))
    bot.send_message(chat_id: User.find_by_username('gildof').uid,
                     text: 'Unbillable lanciato ')

    nwo_service = Authorizer.new(riccardo_uid).service
    unbillable_sheets = nwo_service.get_spreadsheet_values(super_sheet, 'EXPORT!B:C').values
    unbillable_sheets = unbillable_sheets.map do |x|
      x[0] if x[1]&.downcase == 'x' && x[0]&.downcase&.chomp != 'unbillable'
    end.compact

    unbillable_values = nwo_service
                        .get_spreadsheet_values(super_sheet, 'Unsold!D:O')
                        .values

    nwo_sheets_values = {}

    unbillable_sheets.each do |bs|
      nwo_sheets_values[bs] = nwo_service
                              .get_spreadsheet_values(super_sheet, "#{bs}!D:O")
                              .values
    end

    User.find_each do |user|
      # TODO: manage auth fails
      skip = %w[riccardocattaneo17]
      next if skip.include? user.username

      current_name = user.name
      dates.each do |day|
        billable_hours = 0
        unbillable_sheets.each do |bs|
          svalues = nwo_sheets_values[bs]
          svalues.each do |x|
            if x[0..2] == [day.year.to_s, day.month.to_s, current_name]
              billable_hours += x[-1].to_f
            end
          end
        end
        range = unbillable_values
                .index { |x| x[0..2] == [day.year.to_s, day.month.to_s, current_name] }

        next unless range

        unbillable_days = case user.username
                          when 'pasalino'
                            16 - billable_hours
                          when 'Kaiser_Sose'
                            10 - billable_hours
                          else
                            21 - billable_hours
                          end

        unbillable_days = unbillable_days.to_s
        nwo_service.update_spreadsheet_value(super_sheet, "Unsold!O#{range + 1}",
                                             values([[unbillable_days]]),
                                             value_input_option: 'USER_ENTERED')
      end
    end
    ss = Sidekiq::ScheduledSet.new
    jobs = ss.select { |job| job['wrapped'] == 'UnbillableJob' }
    jobs.each(&:delete)

    bot.send_message(chat_id: riccardo_uid, text: 'Unbillable End.')
  end

  private

  def values(values)
    @body = { "values": values }
  end
end
