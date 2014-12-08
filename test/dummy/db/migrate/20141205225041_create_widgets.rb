class CreateWidgets < ActiveRecord::Migration
  def change
    create_table :widgets do |t|
      t.primary_key, :id
      t.binary, :binary
      t.boolean, :boolean
      t.date, :date
      t.datetime, :datetime
      t.decimal, :decimal
      t.float, :float
      t.integer, :integer
      t.references, :widget_details
      t.string, :string
      t.text, :text
      t.time, :time
      t.timestamp, :timestamp
      t.hstore, :hstore
      t.json, :json
      t.array, :array
      t.cidr_address, :cidr_address
      t.ip_address, :ip_address
      t.mac_address :mac_address

      t.timestamps
    end
  end
end
