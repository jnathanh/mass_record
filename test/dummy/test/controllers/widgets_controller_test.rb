require 'test_helper'

class WidgetsControllerTest < ActionController::TestCase
  setup do
    @widget = widgets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:widgets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create widget" do
    assert_difference('Widget.count') do
      post :create, widget: { array: @widget.array, binary: @widget.binary, boolean: @widget.boolean, cidr_address: @widget.cidr_address, date: @widget.date, datetime: @widget.datetime, decimal: @widget.decimal, float: @widget.float, hstore: @widget.hstore, integer: @widget.integer, ip_address: @widget.ip_address, json: @widget.json, mac_address: @widget.mac_address, references_id: @widget.references_id, string: @widget.string, text: @widget.text, time: @widget.time, timestamp: @widget.timestamp }
    end

    assert_redirected_to widget_path(assigns(:widget))
  end

  test "should show widget" do
    get :show, id: @widget
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @widget
    assert_response :success
  end

  test "should update widget" do
    patch :update, id: @widget, widget: { array: @widget.array, binary: @widget.binary, boolean: @widget.boolean, cidr_address: @widget.cidr_address, date: @widget.date, datetime: @widget.datetime, decimal: @widget.decimal, float: @widget.float, hstore: @widget.hstore, integer: @widget.integer, ip_address: @widget.ip_address, json: @widget.json, mac_address: @widget.mac_address, references_id: @widget.references_id, string: @widget.string, text: @widget.text, time: @widget.time, timestamp: @widget.timestamp }
    assert_redirected_to widget_path(assigns(:widget))
  end

  test "should destroy widget" do
    assert_difference('Widget.count', -1) do
      delete :destroy, id: @widget
    end

    assert_redirected_to widgets_path
  end
end
