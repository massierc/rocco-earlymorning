class AddWorkDayToWorkSession < ActiveRecord::Migration[5.1]
  def change
    add_reference :work_sessions, :work_day, foreign_key: true
  end
end
