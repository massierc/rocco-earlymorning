class AddAasmStateToWorkDay < ActiveRecord::Migration[5.1]
  def change
    add_column :work_days, :aasm_state, :string
  end
end
