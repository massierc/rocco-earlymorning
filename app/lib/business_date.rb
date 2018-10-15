module BusinessDate
  def next_business_day(date, options = {})
    if options['hour']
      skip_weekends(Time.new(date.year, date.month, date.mday, options['hour'], 00), 1)
    else
      skip_weekends(eod(date), 1)
    end
  end

  def current_or_next_business_day(date)
    is_day_in_progress(date) && !is_weekend(date) ? eod(date) : next_business_day(date)
  end

  def skip_weekends(date, inc)
    date += inc
    date += inc while is_weekend(date)
    date
  end
  
  def is_weekend(date)
    (date.wday % 7 == 0) || (date.wday % 7 == 6)
  end
  
  def is_day_in_progress(date)
    date.hour < 19
  end

  def eod(day)
    Time.new(day.year, day.month, day.day, 19, 00)
  end
end
