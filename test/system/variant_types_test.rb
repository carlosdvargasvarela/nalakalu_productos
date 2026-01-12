require "application_system_test_case"

class VariantTypesTest < ApplicationSystemTestCase
  setup do
    @variant_type = variant_types(:one)
  end

  test "visiting the index" do
    visit variant_types_url
    assert_selector "h1", text: "Variant types"
  end

  test "should create variant type" do
    visit variant_types_url
    click_on "New variant type"

    fill_in "Name", with: @variant_type.name
    click_on "Create Variant type"

    assert_text "Variant type was successfully created"
    click_on "Back"
  end

  test "should update Variant type" do
    visit variant_type_url(@variant_type)
    click_on "Edit this variant type", match: :first

    fill_in "Name", with: @variant_type.name
    click_on "Update Variant type"

    assert_text "Variant type was successfully updated"
    click_on "Back"
  end

  test "should destroy Variant type" do
    visit variant_type_url(@variant_type)
    click_on "Destroy this variant type", match: :first

    assert_text "Variant type was successfully destroyed"
  end
end
