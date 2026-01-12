require "test_helper"

class VariantTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant_type = variant_types(:one)
  end

  test "should get index" do
    get variant_types_url
    assert_response :success
  end

  test "should get new" do
    get new_variant_type_url
    assert_response :success
  end

  test "should create variant_type" do
    assert_difference("VariantType.count") do
      post variant_types_url, params: { variant_type: { name: @variant_type.name } }
    end

    assert_redirected_to variant_type_url(VariantType.last)
  end

  test "should show variant_type" do
    get variant_type_url(@variant_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_variant_type_url(@variant_type)
    assert_response :success
  end

  test "should update variant_type" do
    patch variant_type_url(@variant_type), params: { variant_type: { name: @variant_type.name } }
    assert_redirected_to variant_type_url(@variant_type)
  end

  test "should destroy variant_type" do
    assert_difference("VariantType.count", -1) do
      delete variant_type_url(@variant_type)
    end

    assert_redirected_to variant_types_url
  end
end
