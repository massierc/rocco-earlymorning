module Utils
  MONTHS = %w[Gennaio Febbraio Marzo Aprile Maggio Giugno Luglio
              Agosto Settembre Ottobre Novembre Dicembre].freeze

  def is_month?(month)
    MONTHS.include? month.strip.downcase.capitalize
  end

  def this_month_sheet
    date = Date.today.strftime('%B %Y').split
    month = month_in_italian(date[0].to_sym)
    (month + ' ' + date.last)
  end

  def month_in_italian(month)
    convert = {
      "January": 'Gennaio',
      "February": 'Febbraio',
      "March": 'Marzo',
      "April": 'Aprile',
      "May": 'Maggio',
      "June": 'Giugno',
      "July": 'Luglio',
      "August": 'Agosto',
      "September": 'Settembre',
      "October": 'Ottobre',
      "November": 'Novembre',
      "December": 'Dicembre'
    }
    month = convert[month]
  end

  def cb_data(current_state, value)
    cb_obj = {
      state: current_state,
      value: value
    }
    cb_obj.to_json
  end

  def duration_in_hours_and_minutes(duration)
    Time.at(duration).utc.strftime('%H:%M')
  end

  def giuditta_uid
    user = Rails.env.development? ? '87171529' : '555036656'
    User.find_by_uid(user).uid
  end

  def riccardo_uid
    user = Rails.env.development? ? 'gildof' : 'riccardocattaneo17'
    User.find_by_username(user).uid
  end

  def em_pm_sheet
    Rails.env.production? ? '1DO9H3l32jZbTwPnHf-Z_logP6Gbsvw2DMnOvw9EK53w' : '1ncFghiRKRymQtC7qAgsLwKC0pRQ0790ZHLaT-0NJ94Y'
  end

  def super_sheet
    Rails.env.production? ? '1XcYUxvaGAnHPfjEWhRZVNjngbj8nUdt86JZ9w6rwnIc' : '1g6Rn0cH_u4ViLDLjlnJDEKcT3rPt-7EaveDbdOtK1TY'
  end
end
