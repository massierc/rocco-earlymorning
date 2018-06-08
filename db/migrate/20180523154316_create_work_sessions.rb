class CreateWorkSessions < ActiveRecord::Migration[5.1]
  def change
    create_table :work_sessions do |t|
      t.references :user, foreign_key: true
      t.datetime :start_date
      t.datetime :end_date
      t.string :client
      t.string :activity

      t.timestamps
    end
  end
end
