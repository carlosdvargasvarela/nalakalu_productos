class UpdateVariantsForFlexibility < ActiveRecord::Migration[7.2]
  def change
    # 1. Permitir que provider_id sea nulo
    change_column_null :variants, :provider_id, true

    # 2. Añadir el nombre comercial para el vendedor
    add_column :variants, :display_name, :string

    # 3. Añadir una descripción técnica opcional
    add_column :variants, :technical_description, :text
  end
end
