# test/controllers/showrooms_controller_test.rb
require "test_helper"

class ShowroomsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
  end

  test "should get index" do
    get showrooms_url
    assert_response :success
  end

  test "should get new" do
    get new_showroom_url
    assert_response :success
  end

  test "should create showroom" do
    assert_difference("Showroom.count") do
      post showrooms_url, params: { showroom: { name: "Sala Nueva", code: "SN", order_number_prefixes: ["4"] } }
    end

    assert_redirected_to showrooms_url
    assert_equal ["4"], Showroom.last.order_number_prefixes_array
  end

  test "should get edit" do
    get edit_showroom_url(@showroom)
    assert_response :success
  end

  test "should update showroom" do
    patch showroom_url(@showroom),
      params: { showroom: { name: @showroom.name, code: @showroom.code, order_number_prefixes: ["2", "3", "5"] } }

    assert_redirected_to showrooms_url
    assert_equal ["2", "3", "5"], @showroom.reload.order_number_prefixes_array
  end

  test "activating is_main on another showroom demotes the previous main" do
    other = showrooms(:escazu)
    patch showroom_url(other), params: { showroom: { name: other.name, code: other.code, is_main: true } }

    assert other.reload.is_main?
    assert_not @showroom.reload.is_main?
  end

  test "should destroy showroom" do
    destroyable = Showroom.create!(name: "Sala Temporal", code: "ST")

    assert_difference("Showroom.count", -1) do
      delete showroom_url(destroyable)
    end

    assert_redirected_to showrooms_url
  end
end
