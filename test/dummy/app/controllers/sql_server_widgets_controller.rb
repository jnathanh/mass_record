class SqlServerWidgetsController < ApplicationController
  before_action :set_sql_server_widget, only: [:show, :edit, :update, :destroy]

  # GET /sql_server_widgets
  def index
    @sql_server_widgets = SqlServerWidget.all
  end

  # GET /sql_server_widgets/1
  def show
  end

  # GET /sql_server_widgets/new
  def new
    @sql_server_widget = SqlServerWidget.new
  end

  # GET /sql_server_widgets/1/edit
  def edit
  end

  # POST /sql_server_widgets
  def create
    @sql_server_widget = SqlServerWidget.new(sql_server_widget_params)

    if @sql_server_widget.save
      redirect_to @sql_server_widget, notice: 'Sql server widget was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /sql_server_widgets/1
  def update
    if @sql_server_widget.update(sql_server_widget_params)
      redirect_to @sql_server_widget, notice: 'Sql server widget was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /sql_server_widgets/1
  def destroy
    @sql_server_widget.destroy
    redirect_to sql_server_widgets_url, notice: 'Sql server widget was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_sql_server_widget
      @sql_server_widget = SqlServerWidget.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def sql_server_widget_params
      params.require(:sql_server_widget).permit(:binary, :boolean, :date, :datetime, :decimal, :float, :integer, :references_id, :string, :text, :time, :timestamp, :hstore, :json, :array, :cidr_address, :ip_address, :mac_address)
    end
end
