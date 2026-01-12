require "application_system_test_case"

class ProvidersTest < ApplicationSystemTestCase
  setup do
    @provider = providers(:one)
  end

  test "visiting the index" do
    visit providers_url
    assert_selector "h1", text: "Providers"
  end

  test "should create provider" do
    visit providers_url
    click_on "New provider"

    check "Active" if @provider.active
    fill_in "Contact name", with: @provider.contact_name
    fill_in "Email", with: @provider.email
    fill_in "Name", with: @provider.name
    fill_in "Notes", with: @provider.notes
    fill_in "Phone", with: @provider.phone
    click_on "Create Provider"

    assert_text "Provider was successfully created"
    click_on "Back"
  end

  test "should update Provider" do
    visit provider_url(@provider)
    click_on "Edit this provider", match: :first

    check "Active" if @provider.active
    fill_in "Contact name", with: @provider.contact_name
    fill_in "Email", with: @provider.email
    fill_in "Name", with: @provider.name
    fill_in "Notes", with: @provider.notes
    fill_in "Phone", with: @provider.phone
    click_on "Update Provider"

    assert_text "Provider was successfully updated"
    click_on "Back"
  end

  test "should destroy Provider" do
    visit provider_url(@provider)
    click_on "Destroy this provider", match: :first

    assert_text "Provider was successfully destroyed"
  end
end
