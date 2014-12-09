class SqlServerWidget < ActiveRecord::Base
  belongs_to :references
  establish_connection "sql_server_#{Rails.env}".to_sym
end
