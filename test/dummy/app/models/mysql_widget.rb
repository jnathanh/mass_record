class MysqlWidget < ActiveRecord::Base
  belongs_to :references
  establish_connection "mysql_#{Rails.env}".to_sym
end
