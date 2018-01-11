class AddWhoToUsers < ActiveRecord::Migration
  def change
    add_column :users, :who, :string
  end
end
