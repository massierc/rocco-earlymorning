module Utils
  def this_month_sheet
    convert = {
      "January": "Gennaio",
      "February": "Febbraio",
      "March": "Marzo",
      "April": "Aprile",
      "May": "Maggio",
      "June": "Giugno",
      "July": "Luglio",
      "August": "Agosto",
      "September": "Settembre",
      "October": "Ottobre",
      "November": "Novembre",
      "December": "Dicembre"
    }

    date = Date.today.strftime("%B %Y").split
    month = convert[(date[0].to_sym)]
    (month + " " + date.last)
  end
end
