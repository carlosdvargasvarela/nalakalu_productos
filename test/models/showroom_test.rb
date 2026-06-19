require "test_helper"

class ShowroomTest < ActiveSupport::TestCase
  test "valid with name and code, normalizes code to uppercase" do
    showroom = Showroom.new(name: "Sala Test", code: "st")
    assert showroom.valid?
    assert_equal "ST", showroom.code
  end

  test "requires name and code" do
    showroom = Showroom.new
    assert_not showroom.valid?
    assert_includes showroom.errors[:name], "can't be blank"
    assert_includes showroom.errors[:code], "can't be blank"
  end

  test "code must be unique case-insensitively" do
    Showroom.create!(name: "Sala Palmares Dup", code: "spd")
    dup = Showroom.new(name: "Otra", code: "SPD")
    assert_not dup.valid?
    assert_includes dup.errors[:code], "has already been taken"
  end

  test "activating is_main demotes any other main showroom" do
    palmares = showrooms(:palmares)
    escazu   = showrooms(:escazu)
    assert palmares.is_main?

    escazu.update!(is_main: true)

    assert escazu.reload.is_main?
    assert_not palmares.reload.is_main?
  end

  test "stores and reads JSON array fields through the *_array helpers" do
    showroom = Showroom.create!(
      name: "Sala Helper", code: "SH",
      order_number_prefixes: ["2", "3"],
      order_number_keywords: ["ESCAZU", " guanacaste "]
    )

    assert_equal ["2", "3"], showroom.reload.order_number_prefixes_array
    assert_equal ["ESCAZU", "guanacaste"], showroom.order_number_keywords_array
  end

  test "array helpers default to an empty array when blank" do
    showroom = Showroom.create!(name: "Sala Vacía", code: "SV")
    assert_equal [], showroom.inter_sala_keywords_array
    assert_equal [], showroom.product_keywords_array
  end

  test "cached_ids refleja altas y bajas de salas" do
    Rails.cache.clear
    before_ids = Showroom.cached_ids

    created = Showroom.create!(name: "Sala Cache", code: "SC")
    assert_includes Showroom.cached_ids, created.id
    refute_includes before_ids, created.id

    created.destroy
    assert_not_includes Showroom.cached_ids, created.id
  end
end
