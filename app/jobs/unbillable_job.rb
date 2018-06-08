class UnbillableJob < ApplicationJob
  queue_as :default
  include Utils

  def perform(*args)
    bot = Telegram.bot
    bot.send_message(chat_id: riccardo_uid, text: 'Unbillable Start...')

    today = Date.today
    I18n.locale = :it

    month_short = I18n.l(today, format: "%b").capitalize
    nwo_service = Authorizer.new(riccardo_uid).service
    sheets_list = nwo_service.get_spreadsheet(super_sheet).sheets

    sheets = sheets_list.collect { |x| x.properties.title }
    unbillable_sheets = nwo_service.get_spreadsheet_values(super_sheet, "EXPORT!B:C").values

    unbillable_sheets = unbillable_sheets.map do |x|
      x[0] if x[1]&.downcase == "x" && x[0]&.downcase.chomp != "unbillable"
    end.compact
    
    unbillable_sheet_values = nwo_service.get_spreadsheet_values(super_sheet, "Unbillable!D:O").values
    bot.send_message(chat_id: User.find_by_username("gildof").uid, text: "Riccardo ha lanciato Unbillable")

    nwo_sheets_values = {}

    unbillable_sheets.each do |bs|
      nwo_sheets_values[bs] = nwo_service.get_spreadsheet_values(super_sheet, "#{bs}!D:O").values
    end
    
    User.find_each do |user|
      # TODO: manage auth fails
      skip = ["riccardocattaneo17", "Kaiser_Sose"]
      if skip.include? user.username
        next
      end

      current_name = user.name

      billable_hours = 0
      unbillable_sheets.each do |bs|
        svalues = nwo_sheets_values[bs]
        svalues.each do |x|
          if x[0..2] == [today.year.to_s, today.month.to_s, current_name]
            billable_hours += x[-1].to_f
          end
        end
      end
      range = unbillable_sheet_values.index{ |x| x[0..2] == [today.year.to_s, today.month.to_s, current_name] }

      if range
        unbillable_days = 21 - billable_hours
        unbillable_days = unbillable_days.to_s
        nwo_service.update_spreadsheet_value(super_sheet, "Unbillable!O#{range+1}", values([[unbillable_days]]), value_input_option: 'USER_ENTERED')
      end
    end
    
    ss = Sidekiq::ScheduledSet.new
    jobs = ss.select {|job| job["wrapped"] == 'UnbillableJob' }
    jobs.each(&:delete)

    bot.send_message(chat_id: riccardo_uid, text: 'Unbillable End.')
  end

  private
  def values(values)
    @body = {"values": values }
  end
end
