class RiccardoJob < ApplicationJob
  queue_as :default
  include Utils

  def perform(*_args)
    today = Date.today
    I18n.locale = :it
    month_short = I18n.l(today, format: "%b").capitalize
    nwo_service = Authorizer.new(riccardo_uid).service
    sheets_list = nwo_service.get_spreadsheet(super_sheet).sheets
    sheets = sheets_list.collect { |x| x.properties.title }

    User.where(company_id: 0).each do |user|
      # TODO: manage auth fails
      # if user.username == "kiaroskuro"
      #   next
      # end

      begin
        begin
          service = Authorizer.new(user.uid).service
        rescue
          service = Authorizer.new(riccardo_uid).service
        end

        if _args.length > 0 && is_month?(_args[0])
          month = _args[0].strip.downcase.capitalize
          year = Date.today.strftime("%Y")
          month_sheet = "#{month} #{year}"
        else
          month_sheet = this_month_sheet
        end

        projects = service.get_spreadsheet_values(user.sheet_id, "#{month_sheet}!A:D").values
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
            user.name = current_name
            user.save

            if cells[s].kind_of?(Hash)
              cells[s][p[2]] = p[-1].to_f
            else
              cells[s] += p[-1].to_f
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
    end

    ss = Sidekiq::ScheduledSet.new
    jobs = ss.select {|job| job["wrapped"] == 'RiccardoJob' }
    jobs.each(&:delete)
    RiccardoJob.set(wait_until: 1.day.from_now.change({hour: 20})).perform_later( )
    UnbillableJob.set(wait: 2.minutes).perform_later( )
    bot = Telegram.bot
    bot.send_message(chat_id: riccardo_uid, text: 'NWO Completato')
  end

  private
  def values(values)
    @body = {"values": values }
  end
end
