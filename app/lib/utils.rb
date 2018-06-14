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

  def giuditta_uid
      user = if Rails.env.development?
      "87171529"
    else
      "555036656"
    end
    User.find_by_uid(user).uid
  end
  


  def riccardo_uid
    user = if Rails.env.development?
      "gildof"
    else
      "riccardocattaneo17"
    end
    User.find_by_username(user).uid
  end

  def em_pm_sheet
    "1DO9H3l32jZbTwPnHf-Z_logP6Gbsvw2DMnOvw9EK53w"
  end

  def super_sheet
    if Rails.env.production?
      '1XcYUxvaGAnHPfjEWhRZVNjngbj8nUdt86JZ9w6rwnIc'
    else
      '1g6Rn0cH_u4ViLDLjlnJDEKcT3rPt-7EaveDbdOtK1TY'
    end
  end
end
