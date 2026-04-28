# rails generate migration ChangeStockSalaLabelToArray
class ChangeStockSalaLabelToArray < ActiveRecord::Migration[7.2]
  def change
    rename_column :code_settings, :stock_sala_label, :stock_sala_options
    change_column :code_settings, :stock_sala_options, :text
  end
end
