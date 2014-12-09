require 'test_helper'

class WidgetsHelperTest < ActionView::TestCase
	def generate number, of:Widgets
		records = []
		number.times do |x|
			test_record = of.new
			test_record.binary= get_binary 
			test_record.boolean= false
			test_record.date= 2014-12-08
			test_record.datetime= 2014-12-08 22=14=12
			test_record.decimal= 9.99
			test_record.float= 1.5
			test_record.integer= 1
			test_record.references_id= 32
			test_record.string= MyString
			test_record.text= MyText
			test_record.time= 2014-12-08 22=14=12
			test_record.timestamp= 2014-12-08 22=14=12
			test_record.hstore= MyText
			test_record.json= MyText
			test_record.array= MyText
			test_record.cidr_address= MyText
			test_record.ip_address= MyText
			test_record.mac_address= MyText

		end
	end

	def get_binary

	end
end
