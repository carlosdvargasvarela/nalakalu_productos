class CreateChangeLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :change_logs do |t|
      t.string :batch_id, null: false      # un lote = una acción del usuario (una petición)
      t.references :user, foreign_key: true
      t.string :record_type, null: false
      t.integer :record_id, null: false
      t.string :record_label
      t.string :action, null: false        # create / update / destroy
      t.json :before_data                  # update: solo columnas cambiadas; destroy: fila completa
      t.json :after_data
      t.string :label                      # descripción del lote
      t.datetime :undone_at
      t.references :undone_by, foreign_key: {to_table: :users}
      t.datetime :created_at, null: false
    end
    add_index :change_logs, :batch_id
    add_index :change_logs, [:record_type, :record_id]
  end
end
