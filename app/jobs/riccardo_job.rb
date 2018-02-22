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

  def perform(*_args)
    today = Date.today
    # TODO: Fogli corretti
    super_sheet = '1g6Rn0cH_u4ViLDLjlnJDEKcT3rPt-7EaveDbdOtK1TY'

    service = Authorizer.new(riccardo_uid).service
    sheets = service.get_spreadsheet(super_sheet).sheets.collect { |x| x.properties.title }

    User.find_each do |user|
      # TODO: manage auth fails
      if user.username == "kiaroskuro"
        next
      end

      begin
        projects = service.get_spreadsheet_values(user.sheet_id, "#{this_month_sheet}!A:D").values
        cells = Hash[sheets.map {|x| [x, 0]}]
        # TODO: Rescuing here does not work
      rescue Google::Apis::ClientError => e
        puts e
        next
      end


      current_name = nil

      sheets.each do |s|
        projects.each_with_index do |p, i|
          if p[1].downcase.strip.include?(s.downcase.strip) && p[1]
            current_name = p[0].capitalize
            cells[s] += p[-1].to_i
          end
        end
      end

      cells.each do |k,v|
        if v > 0
          svalues = service.get_spreadsheet_values(super_sheet, "#{k}!D:F").values
          range = svalues.index([today.year.to_s, today.month.to_s, current_name])
          if range
            range += 1
          else
            range = svalues.length + 1
          end

          val = [[today.year.to_s, today.month.to_s, current_name, "Sviluppo #{today.strftime('%b')}",
            nil, nil,
            v / 8.0,
            nil, nil, nil, nil,
            v / 8.0]]

          service.update_spreadsheet_value(super_sheet, "#{k}!D#{range}", values(val), value_input_option: 'USER_ENTERED')
        end
      end
    end

  end

  private
  def values(values)
    @body = {"values": values }
  end
end
