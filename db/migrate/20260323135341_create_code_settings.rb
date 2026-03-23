class CreateCodeSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :code_settings do |t|
      t.string :name, default: "Configuración General"
      t.integer :max_chars_per_line, default: 30
      t.integer :max_lines, default: 5
      t.string :default_separator, default: "-"
      t.boolean :show_stock_sala, default: true
      t.string :stock_sala_label, default: "STOCK DE SALA"
      t.boolean :use_prefixes, default: true
      t.integer :prefix_length, default: 3

      t.timestamps
    end
  end
end
