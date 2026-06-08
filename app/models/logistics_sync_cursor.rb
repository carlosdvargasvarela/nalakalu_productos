class LogisticsSyncCursor < ApplicationRecord
  def self.current
    first_or_create!
  end

  # Avanza el cursor solo si el nuevo valor es más reciente que el actual.
  # Así, una corrida que procesa entregas fuera de orden nunca retrocede
  # el punto de partida de la siguiente sincronización incremental.
  def advance_to!(timestamp)
    return if timestamp.blank?

    if timestamp.is_a?(String)
      timestamp = begin
        Time.zone.parse(timestamp)
      rescue ArgumentError, TypeError
        nil
      end
    end
    return if timestamp.nil?
    return if last_synced_at.present? && timestamp <= last_synced_at

    update!(last_synced_at: timestamp)
  end
end
