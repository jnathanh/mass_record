require 'test_helper'

class SqlServerWidgetsControllerTest < ActionController::TestCase
  setup do
    @sql_server_widget = sql_server_widgets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sql_server_widgets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sql_server_widget" do
    assert_difference('SqlServerWidget.count') do
      post :create, sql_server_widget: { array: @sql_server_widget.array, binary: @sql_server_widget.binary, boolean: @sql_server_widget.boolean, cidr_address: @sql_server_widget.cidr_address, date: @sql_server_widget.date, datetime: @sql_server_widget.datetime, decimal: @sql_server_widget.decimal, float: @sql_server_widget.float, hstore: @sql_server_widget.hstore, integer: @sql_server_widget.integer, ip_address: @sql_server_widget.ip_address, json: @sql_server_widget.json, mac_address: @sql_server_widget.mac_address, references_id: @sql_server_widget.references_id, string: @sql_server_widget.string, text: @sql_server_widget.text, time: @sql_server_widget.time, timestamp: @sql_server_widget.timestamp }
    end

    assert_redirected_to sql_server_widget_path(assigns(:sql_server_widget))
  end

  test "should show sql_server_widget" do
    get :show, id: @sql_server_widget
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sql_server_widget
    assert_response :success
  end

  test "should update sql_server_widget" do
    patch :update, id: @sql_server_widget, sql_server_widget: { array: @sql_server_widget.array, binary: @sql_server_widget.binary, boolean: @sql_server_widget.boolean, cidr_address: @sql_server_widget.cidr_address, date: @sql_server_widget.date, datetime: @sql_server_widget.datetime, decimal: @sql_server_widget.decimal, float: @sql_server_widget.float, hstore: @sql_server_widget.hstore, integer: @sql_server_widget.integer, ip_address: @sql_server_widget.ip_address, json: @sql_server_widget.json, mac_address: @sql_server_widget.mac_address, references_id: @sql_server_widget.references_id, string: @sql_server_widget.string, text: @sql_server_widget.text, time: @sql_server_widget.time, timestamp: @sql_server_widget.timestamp }
    assert_redirected_to sql_server_widget_path(assigns(:sql_server_widget))
  end

  test "should destroy sql_server_widget" do
    assert_difference('SqlServerWidget.count', -1) do
      delete :destroy, id: @sql_server_widget
    end

    assert_redirected_to sql_server_widgets_path
  end
end
