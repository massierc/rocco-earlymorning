class UnbillableJob < ApplicationJob
  queue_as :default
  include Utils


  def perform(*args)
    today = Date.today
    
    month_short = I18n.l(today, format: "%b").capitalize
    nwo_service = Authorizer.new(riccardo_uid).service
    sheets_list = nwo_service.get_spreadsheet(super_sheet).sheets

    sheets = sheets_list.collect { |x| x.properties.title }
    billable_sheets = sheets[0..sheets.index("Unbillable")-1]
    unbillable_sheet_values = nwo_service.get_spreadsheet_values(super_sheet, "Unbillable!D:O").values

    User.find_each do |user|
      # TODO: manage auth fails
      if user.username == "kiaroskuro"
        next
      end

      begin
        service = Authorizer.new(user.uid).service
        projects = service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!A:D").values
        cells = Hash[sheets.map {|x| [x, 0]}]
      rescue Google::Apis::ClientError => e
        puts e
        next
      end

      current_name = user.name

      billable_hours = 0
      billable_sheets.each do |bs|
        svalues = nwo_service.get_spreadsheet_values(super_sheet, "#{bs}!D:O").values
        svalues.each do |x|
          if x[0..2] == [today.year.to_s, today.month.to_s, current_name]
            billable_hours += x[-1].to_f
          end
        end
      end
      range = unbillable_sheet_values.index{ |x| x[0..2] == [today.year.to_s, today.month.to_s, current_name] }

      if range
        unbillable_days = 21 - (billable_hours / 8)
        unbillable_days = sprintf( "%0.02f", unbillable_days)
        nwo_service.update_spreadsheet_value(super_sheet, "Unbillable!O#{range+1}", values([[unbillable_days]]), value_input_option: 'USER_ENTERED')
      end
    end
    
    ss = Sidekiq::ScheduledSet.new
    jobs = ss.select {|job| job["wrapped"] == 'UnbillableJob' }
    jobs.each(&:delete)

  end

  private
  def values(values)
    @body = {"values": values }
  end
end
