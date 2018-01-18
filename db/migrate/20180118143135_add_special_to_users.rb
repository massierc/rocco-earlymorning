class AddSpecialToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :special, :boolean, default: false
  end
end
