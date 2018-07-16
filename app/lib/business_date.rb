module BusinessDate
  def next_business_day(date)
    skip_weekends(date, 1)
  end

  def previous_business_day(date)
    skip_weekends(date, -1)
  end

  def skip_weekends(date, inc)
    date += inc
    date += inc while (date.wday % 7 == 0) || (date.wday % 7 == 6)
    date
  end

  def eod(day)
    Time.new(day.year, day.month, day.day, 19, 00)
  end
end
