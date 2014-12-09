class Widget < ActiveRecord::Base
  belongs_to :references
  establish_connection Rails.env.to_sym
end
