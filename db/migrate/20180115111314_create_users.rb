class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.integer :uid
      t.integer :level, default: 0
      t.string :what
      t.string :howmuch
      t.string :who
      t.string :username
      t.string :sheet_id
      t.string :jid
      t.integer :setup, default: 3
      t.timestamps
    end
  end
end
