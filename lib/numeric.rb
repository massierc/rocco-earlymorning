class Numeric
  Alpha26 = ('a'..'z').to_a
  def to_s26
    return '' if self < 1
    s = ''
    q = self
    loop do
      q, r = (q - 1).divmod(26)
      s.prepend(Alpha26[r])
      break if q.zero?
    end
    s
  end
end

class String
  Alpha26 = ('a'..'z').to_a

  def to_i26
    result = 0
    downcase!
    (1..length).each do |i|
      char = self[-i]
      result += 26**(i - 1) * (Alpha26.index(char) + 1)
    end
    result
  end

  def to_sheet_range(sheet_id)
    columnIndex = []
    rowIndex = []
    self.each_char.with_index do |c,i|
      if c == ":"
        next
      elsif !/\A\d+\z/.match(c)
        columnIndex << c
      elsif
        rowIndex << c
      end
    end

    column = columnIndex.join.to_i26
    row = rowIndex.join.to_i
    result = {
      sheet_id: sheet_id,
      start_row_index: row - 1,
      end_row_index: row,
      start_column_index: column -1,
      end_column_index: column
    }
  end
end
