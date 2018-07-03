class AddDateToWorkDay < ActiveRecord::Migration[5.1]
  def change
    add_column :work_days, :date, :date
  end
end
