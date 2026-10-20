class ChangeLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :undone_by, class_name: "User", optional: true

  class Conflict < StandardError; end

  scope :pending, -> { where(undone_at: nil) }

  def self.log(record, action, before, after)
    return if Current.skip_log || Current.batch_id.blank?

    create!(batch_id: Current.batch_id, user_id: Current.user&.id, record_type: record.class.base_class.name, record_id: record.id,
      record_label: label_for(record), action: action, before_data: before, after_data: after, label: Current.label)
  end

  # Para cambios masivos con update_all: registra cada fila y luego aplica.
  def self.bulk_update(scope, attrs)
    records = scope.to_a
    records.each { |r| log(r, "update", attrs.keys.to_h { [_1.to_s, r[_1]] }, attrs.stringify_keys) }
    scope.update_all(attrs.merge(updated_at: Time.current))
    records.size
  end

  def self.label_for(record)
    record.try(:seller_name) || record.try(:name) || record.class.model_name.human
  end

  # Lotes recientes, del más nuevo al más viejo: { batch_id => [filas] }
  def self.batches(limit: 200, record: nil)
    scope = order(id: :desc)
    scope = scope.where(batch_id: where(record_type: record.class.base_class.name, record_id: record.id).select(:batch_id)) if record
    scope.limit(limit * 20).group_by(&:batch_id).first(limit).to_h
  end

  def self.undoable?(batch_id)
    conflicts(batch_id).empty? && where(batch_id: batch_id).pending.exists?
  end

  # Filas del lote que tienen cambios posteriores de otros lotes (deshacer pisaría ese trabajo)
  def self.conflicts(batch_id)
    rows = where(batch_id: batch_id).pending
    last = rows.maximum(:id).to_i
    rows.select do |r|
      pending.where(record_type: r.record_type, record_id: r.record_id).where("id > ?", last).where.not(batch_id: batch_id).exists?
    end
  end

  def self.undo_batch!(batch_id, user)
    raise Conflict, "Hay cambios posteriores sobre estos registros; deshazlos primero." if conflicts(batch_id).any?

    rows = where(batch_id: batch_id).pending.order(id: :desc).to_a
    raise Conflict, "Este cambio ya se deshizo." if rows.empty?

    transaction do
      Current.skip_log = true
      rows.each do |r|
        klass = r.record_type.constantize
        case r.action
        when "create"
          # FamilyVariantRule: su before_destroy borra las reglas de los productos de la familia (efecto lateral que no corresponde al deshacer)
          (klass == FamilyVariantRule) ? klass.where(id: r.record_id).delete_all : klass.find_by(id: r.record_id)&.destroy
        when "update" then klass.where(id: r.record_id).update_all(r.before_data)
        when "destroy" then klass.insert_all!([r.before_data])
        end
      end
      where(id: rows.map(&:id)).update_all(undone_at: Time.current, undone_by_id: user&.id)
    end
    Rails.cache.clear
    rows.size
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    raise Conflict, "No se pudo restaurar (¿ya existe un registro igual?): #{e.message.lines.first}"
  ensure
    Current.skip_log = false
  end

  def summary
    "#{ {"create" => "creó", "update" => "editó", "destroy" => "eliminó"}[action] } #{record_type.constantize.model_name.human.downcase} «#{record_label}»"
  rescue NameError
    "#{action} #{record_type} #{record_id}"
  end
end
