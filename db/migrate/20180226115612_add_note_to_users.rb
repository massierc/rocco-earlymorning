class AddNoteToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :note, :string
  end
end
