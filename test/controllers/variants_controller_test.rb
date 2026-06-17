require "test_helper"

class VariantsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @variant = variants(:one)
  end

  test "should get index" do
    get variants_url
    assert_response :success
  end

  test "should get new" do
    get new_variant_url
    assert_response :success
  end

  test "should create variant" do
    assert_difference("Variant.count") do
      post variants_url, params: { variant: { active: @variant.active, code: @variant.code, display_name: @variant.display_name, name: @variant.name, technical_description: @variant.technical_description, variant_type_id: @variant.variant_type_id } }
    end

    assert_redirected_to variants_path(selected_id: Variant.last.id)
  end

  test "should show variant" do
    get variant_url(@variant)
    assert_response :success
  end

  test "should get edit" do
    get edit_variant_url(@variant)
    assert_response :success
  end

  test "should update variant" do
    patch variant_url(@variant), params: { variant: { active: @variant.active, code: @variant.code, display_name: @variant.display_name, name: @variant.name, technical_description: @variant.technical_description, variant_type_id: @variant.variant_type_id } }
    assert_redirected_to variants_path(selected_id: @variant.id)
  end

  test "should destroy variant" do
    assert_difference("Variant.count", -1) do
      delete variant_url(@variant)
    end

    assert_redirected_to variants_url
  end
end
