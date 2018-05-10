class RiccardoJob < ApplicationJob
  queue_as :default
  include Utils

  def riccardo_uid
    user = if Rails.env.development?
      "gildof"
    else
      "riccardocattaneo17"
    end
    User.find_by_username(user).uid
  end

  def super_sheet
    if Rails.env.production?
      '1RTNQUTh3oLnT1UL7rJgMoQAz5Uuhth99hAYtxWjOKvI'
    else
      '1g6Rn0cH_u4ViLDLjlnJDEKcT3rPt-7EaveDbdOtK1TY'
    end
  end

  def perform(*_args)
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
        # TODO: Rescuing here does not work
      rescue Google::Apis::ClientError => e
        puts e
        next
      end

      current_name = nil
    
      sheets.each do |s|
        cells[s] = {}

        projects.each_with_index do |p, i|
          if !p.empty? && p[1].downcase.strip == s.downcase.strip
            current_name = p[0]

            if cells[s].kind_of?(Hash)
              cells[s][p[2]] = p[-1].to_i
            else
              cells[s] += p[-1].to_i
            end

          end
        end

      end

      cells.each do |k,v|
        v.each do |activity,vv|
          next if vv <= 0
          svalues = nwo_service.get_spreadsheet_values(super_sheet, "#{k}!D:G").values
          range = svalues.index([today.year.to_s, today.month.to_s, current_name, "#{activity} #{month_short}"])
          if range
            range += 1
          else
            range = svalues.length + 1
          end

          val = [[today.year.to_s, today.month.to_s, current_name, "#{activity} #{month_short}",
            nil, nil,
            vv / 8.0,
            nil, nil, nil, nil,
            vv / 8.0]]

          nwo_service.update_spreadsheet_value(super_sheet, "#{k}!D#{range}", values(val), value_input_option: 'USER_ENTERED')
        end
      end

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
    jobs = ss.select {|job| job["wrapped"] == 'RiccardoJob' }
    jobs.each(&:delete)
    RiccardoJob.set(wait_until: DateTime.now.tomorrow.change({hour: 20})).perform_later( )
  end

  private
  def values(values)
    @body = {"values": values }
  end
end
