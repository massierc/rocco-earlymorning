class RiccardoJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    today = Date.today
    # TODO: Fogli corretti

    base_sheet = '1yu269O8geQD2esNvoEhUMJy-yrCrtmB_bENVMfih5YE'
    out_sheet = '1b62PIL3l1EyatpUHOyXCeIC2Zyf_X4JM8v33W3HfoWA'

    # TODO: Iterare gli utenti
    user = Authorizer.new('87171529')

    sheets = user.service.get_spreadsheet(out_sheet).sheets.collect { |x| x.properties.title }

    # TODO: Mese corrente
    projects = user.service.get_spreadsheet_values(base_sheet, "Febbraio 2018!B:D").values
    cells = Hash[sheets.map {|x| [x, 0]}]

    sheets.each do |s|
      projects.each_with_index do |p, i|
        # TODO: SIMILARITY
        cells[s] += p[-1].to_i if p[0].downcase.include?(s.downcase) && p[0]
      end
    end
     a = []
    cells.each do |k,v|
      if v > 0
        s = user.service.get_spreadsheet_values(out_sheet, "#{k}!D:F").values
        # TODO: Name
        c = s.index([today.year, today.month, "Gildo"])

        if c
          c =+ 1
        else
          c = s.length + 1
        end

        val = [[today.year, today.month, 'Gildos', "Sviluppo #{today.strftime('%b')}",
          nil, nil,
          v / 8.0,
          nil, nil, nil, nil,
          v / 8.0]]

        x = user.service.update_spreadsheet_value(out_sheet, "#{k}!D#{c}", values(val), value_input_option: 'USER_ENTERED')
      end
    end

  end

  private
  def values(values)
    @body = {"values": values }
  end
end
