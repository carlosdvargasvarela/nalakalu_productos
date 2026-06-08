class LogisticsSyncCursor < ApplicationRecord
  def self.current
    first_or_create!
  end

  # Avanza el cursor solo si el nuevo valor es más reciente que el actual.
  # Así, una corrida que procesa entregas fuera de orden nunca retrocede
  # el punto de partida de la siguiente sincronización incremental.
  def advance_to!(timestamp)
    return if timestamp.blank?

    timestamp = timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp
    return if last_synced_at.present? && timestamp <= last_synced_at

    update!(last_synced_at: timestamp)
  end
end
