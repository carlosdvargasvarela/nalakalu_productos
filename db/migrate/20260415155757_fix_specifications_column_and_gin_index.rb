# rails g migration FixSpecificationsColumnAndGinIndex
class FixSpecificationsColumnAndGinIndex < ActiveRecord::Migration[7.2]
  def up
    # Cambiar json → jsonb (PostgreSQL lo hace con USING cast)
    execute <<~SQL
      ALTER TABLE procurement_requirements
        ALTER COLUMN specifications TYPE jsonb
        USING specifications::jsonb;
    SQL

    # Agregar índice GIN ahora que es jsonb
    add_index :procurement_requirements, :specifications,
      using: :gin,
      name: "index_procurement_requirements_on_specifications_gin"
  end

  def down
    remove_index :procurement_requirements, name: "index_procurement_requirements_on_specifications_gin"

    execute <<~SQL
      ALTER TABLE procurement_requirements
        ALTER COLUMN specifications TYPE json
        USING specifications::text::json;
    SQL
  end
end
