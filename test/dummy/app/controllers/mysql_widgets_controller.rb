class MysqlWidgetsController < ApplicationController
  before_action :set_mysql_widget, only: [:show, :edit, :update, :destroy]

  # GET /mysql_widgets
  def index
    @mysql_widgets = MysqlWidget.all
  end

  # GET /mysql_widgets/1
  def show
  end

  # GET /mysql_widgets/new
  def new
    @mysql_widget = MysqlWidget.new
  end

  # GET /mysql_widgets/1/edit
  def edit
  end

  # POST /mysql_widgets
  def create
    @mysql_widget = MysqlWidget.new(mysql_widget_params)

    if @mysql_widget.save
      redirect_to @mysql_widget, notice: 'Mysql widget was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /mysql_widgets/1
  def update
    if @mysql_widget.update(mysql_widget_params)
      redirect_to @mysql_widget, notice: 'Mysql widget was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /mysql_widgets/1
  def destroy
    @mysql_widget.destroy
    redirect_to mysql_widgets_url, notice: 'Mysql widget was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mysql_widget
      @mysql_widget = MysqlWidget.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def mysql_widget_params
      params.require(:mysql_widget).permit(:binary, :boolean, :date, :datetime, :decimal, :float, :integer, :references_id, :string, :text, :time, :timestamp, :hstore, :json, :array, :cidr_address, :ip_address, :mac_address)
    end
end
