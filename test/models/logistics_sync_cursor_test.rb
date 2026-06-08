require "test_helper"

class LogisticsSyncCursorTest < ActiveSupport::TestCase
  setup { LogisticsSyncCursor.delete_all }

  test "current crea (o devuelve) el registro singleton" do
    cursor = LogisticsSyncCursor.current
    assert cursor.persisted?
    assert_nil cursor.last_synced_at

    assert_equal cursor, LogisticsSyncCursor.current
    assert_equal 1, LogisticsSyncCursor.count
  end

  test "advance_to! solo avanza hacia adelante en el tiempo" do
    cursor = LogisticsSyncCursor.current
    older = Time.zone.parse("2026-06-01T00:00:00Z")
    newer = Time.zone.parse("2026-06-07T00:00:00Z")

    cursor.advance_to!(newer)
    assert_equal newer, cursor.reload.last_synced_at

    cursor.advance_to!(older)
    assert_equal newer, cursor.reload.last_synced_at, "no debe retroceder el cursor"

    even_newer = Time.zone.parse("2026-06-08T00:00:00Z")
    cursor.advance_to!(even_newer)
    assert_equal even_newer, cursor.reload.last_synced_at
  end

  test "advance_to! ignora valores nil o en blanco" do
    cursor = LogisticsSyncCursor.current
    cursor.advance_to!(nil)
    assert_nil cursor.reload.last_synced_at
  end

  test "advance_to! parsea y guarda un timestamp recibido como string ISO8601" do
    cursor = LogisticsSyncCursor.current

    cursor.advance_to!("2026-06-07T00:00:00Z")

    assert_equal Time.zone.parse("2026-06-07T00:00:00Z"), cursor.reload.last_synced_at
  end

  test "advance_to! ignora strings con formato inválido sin lanzar error" do
    cursor = LogisticsSyncCursor.current
    newer = Time.zone.parse("2026-06-07T00:00:00Z")
    cursor.advance_to!(newer)

    assert_nothing_raised do
      cursor.advance_to!("no-es-una-fecha-valida")
    end

    assert_equal newer, cursor.reload.last_synced_at, "el cursor no debe cambiar ante un string inválido"
  end
end
