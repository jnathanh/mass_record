ActiveRecord::Base.establish_connection("mysql_#{Rails.env}".to_sym)
class CreateMysqlWidgets < ActiveRecord::Migration
  def change
    create_table :mysql_widgets do |t|
      t.binary :binary
      t.boolean :boolean
      t.date :date
      t.datetime :datetime
      t.decimal :decimal
      t.float :float
      t.integer :integer
      t.references :references, index: true
      t.string :string
      t.text :text
      t.time :time
      t.timestamp :timestamp
      t.text :hstore
      t.text :json
      t.text :array
      t.text :cidr_address
      t.text :ip_address
      t.text :mac_address

      t.timestamps
    end
  end
end
