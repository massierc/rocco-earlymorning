class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users, force: true do |t|
      t.integer :uid
      t.integer :level, default: 0
      t.string :what
      t.string :howmuch
      t.string :username
      t.string :sheet_id
      t.string :jid
      t.integer :setup, default: 2
    end
  end
end
