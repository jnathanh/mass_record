require 'test_helper'

class MysqlWidgetsControllerTest < ActionController::TestCase
  setup do
    @mysql_widget = mysql_widgets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:mysql_widgets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create mysql_widget" do
    assert_difference('MysqlWidget.count') do
      post :create, mysql_widget: { array: @mysql_widget.array, binary: @mysql_widget.binary, boolean: @mysql_widget.boolean, cidr_address: @mysql_widget.cidr_address, date: @mysql_widget.date, datetime: @mysql_widget.datetime, decimal: @mysql_widget.decimal, float: @mysql_widget.float, hstore: @mysql_widget.hstore, integer: @mysql_widget.integer, ip_address: @mysql_widget.ip_address, json: @mysql_widget.json, mac_address: @mysql_widget.mac_address, references_id: @mysql_widget.references_id, string: @mysql_widget.string, text: @mysql_widget.text, time: @mysql_widget.time, timestamp: @mysql_widget.timestamp }
    end

    assert_redirected_to mysql_widget_path(assigns(:mysql_widget))
  end

  test "should show mysql_widget" do
    get :show, id: @mysql_widget
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @mysql_widget
    assert_response :success
  end

  test "should update mysql_widget" do
    patch :update, id: @mysql_widget, mysql_widget: { array: @mysql_widget.array, binary: @mysql_widget.binary, boolean: @mysql_widget.boolean, cidr_address: @mysql_widget.cidr_address, date: @mysql_widget.date, datetime: @mysql_widget.datetime, decimal: @mysql_widget.decimal, float: @mysql_widget.float, hstore: @mysql_widget.hstore, integer: @mysql_widget.integer, ip_address: @mysql_widget.ip_address, json: @mysql_widget.json, mac_address: @mysql_widget.mac_address, references_id: @mysql_widget.references_id, string: @mysql_widget.string, text: @mysql_widget.text, time: @mysql_widget.time, timestamp: @mysql_widget.timestamp }
    assert_redirected_to mysql_widget_path(assigns(:mysql_widget))
  end

  test "should destroy mysql_widget" do
    assert_difference('MysqlWidget.count', -1) do
      delete :destroy, id: @mysql_widget
    end

    assert_redirected_to mysql_widgets_path
  end
end
