require "mass_record/engine"

module MassRecord
	mattr_accessor :path, :folder_path, :database_connection
	self.path = {}
	self.folder_path = "tmp/#{Rails.env}"
	self.path[:queries] = "tmp/#{Rails.env}"
	self.path[:queued_queries] = "tmp/#{Rails.env}"
	self.path[:errored_queries] = "tmp/#{Rails.env}"
	self.path[:completed_queries] = "tmp/#{Rails.env}"

	module Actions
		path = {}
		folder_path = "tmp/#{Rails.env}"
		path[:queries] = "#{folder_path}/queries"
		path[:queued_queries] = "#{path[:queries]}/queued"
		path[:errored_queries] = "#{path[:queries]}/errored"
		path[:completed_queries] = "#{path[:queries]}/completed"

		# accepts an array of objects with the option to specify what rails operation to perform
		def queue_for_quick_query object_array, 
			operation: :save, 
			folder:{queued:path[:queued_queries]}, 
			file_tag:Time.now.strftime("%Y%m%d%H%M%S").to_s,
			key:{
				table: "table",
				operation: "operation",
				object: "object"			
			}

			object_array = [object_array] unless object_array.is_a? Array
			queue = []

			object_array.each do |object|
				queue << {key[:table] => object.class.table_name, key[:operation] =>  operation, key[:object] => object} unless object.blank?
			end

			File.open(folder[:queued]+"/#{operation.to_s}_#{file_tag}.json",'w'){|f| f.write queue.to_json}
		end

		def execute_queued_queries key:{
				operation:"operation", 
				table:"table", 
				object:"object"
			},synonyms:{
				insert: [:create, :new, :add, :insert, :post],
				update: [:update,:edit,:modify,:put,:patch],
				select: [:read,:select,:get]
			},folder:{
				queued:path[:queued_queries],
				errored:path[:errored_queries],
				completed:path[:completed_queries]
			},file_tag:Time.now.strftime("%Y%m%d%H%M%S").to_s

			files = Dir.foreach(folder[:queued]).collect{|x| x}.keep_if{|y|y=~/\.json$/i}
			json_objects = []

			# rename to avoid double processing
			files.each{|x| File.rename "#{folder[:queued]}/#{x}","#{folder[:queued]}/#{x}.processing"}

			# load all the json
			files.each do |file|
				File.open("#{folder[:queued]}/#{file}.processing",'r') do |f|
					json = JSON.parse(f.read)
					json_objects += json
				end
			end

			# validate all objects
			json_objects = mass_validate json_objects

			# get all operations and tables in use
			operations = json_objects.collect{|x| x[key[:operation]].to_sym}.to_set.to_a

			# open database connection
			database_connection = ActiveRecord::Base.connection

			# construct mass queries
			errors = {}
			operations.each do |op|
				if synonyms[:insert].include? op
					errors[:insert] = mass_insert_by_table json_objects.select{|x| synonyms[:insert].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:update].include? op
					errors[:update] = mass_update_by_table json_objects.select{|x| synonyms[:update].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif op == :save	# needs to intelligently determine if the order already exists, insert if not, update if so
					errors[:save] = mass_save_by_table json_objects.select{|x| :save == x[key[:operation]].to_sym.downcase}, key:key
				elsif op == :delete
				elsif synonyms[:select].include? op
				else
				end
			end

			# close database connection
			database_connection.close

			# move to appropriate folder and remove '.processing' from the filename
			files = Dir.foreach(folder[:queued]).collect{|x| x}.keep_if{|y|y=~/\.json\.processing$/i}
			errors_present = errors.any?{|op,h| h.any?{|table,a| a.count > 0 }}
			files.each{|x| File.rename "#{folder[:queued]}/#{x}","#{errors_present ? folder[:errored] : folder[:completed]}/group_#{file_tag}_#{x.gsub /\.processing$/,''}"}

			return errors
		end

		def mass_validate objects
			# TODO: write logic, should return only valid objects
			return objects
		end

		def mass_update_by_table json_objects, key:{}
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = {}
				tables.each do |table|
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
					errors[table.to_sym] = mass_update hashes, into:table
				end
				return errors
			rescue Exception => e
				return {method:e} unless defined? errors
				errors[:method] = e if defined? errors
				return errors
			end
		end

		def mass_save_by_table json_objects, key:{}
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = {}
				tables.each do |table|
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
					model = table.classify.constantize
					pk = model.primary_key

					# organize hashes based on whether they exist (based on their primary key(s)) in the table or not
					if pk.is_a? Array
						ids = hashes.reject{|x| pk.any?{|k| x[k].blank?}}.collect{|x| x.select{|k,v| pk.include? k}}	# only accept full sets of pk's
						where_clauses = []
						ids.each do |id|
							equivalence_clauses = []
							id.each do |k,v|
								equivalence_clauses << "#{ActiveRecord::Base.connection.quote_column_name k} = #{ActiveRecord::Base.connection.quote(ActiveRecord::Base.connection.type_cast(v, model.column_types[k]))}"
							end
							where_clauses << "(#{equivalence_clauses.join ' and '})"
						end
						existing_id_sets = ActiveRecord::Base.connection.execute("SELECT #{pk.join ', '} FROM #{table} WHERE #{where_clauses.join ' OR '}").collect{|x| Hash[x.map.with_index{|x,i| [pk[i],x]}]}
						insert_hashes = hashes.reject{|h| existing_id_sets.any?{|set| h == h.merge(set)}}
						update_hashes = hashes.select{|h| existing_id_sets.any?{|set| h == h.merge(set)}}
					else
						ids = hashes.reject{|x| x[pk].blank?}.collect{|x| x[pk]}	# should not include null values
						existing_ids = ActiveRecord::Base.connection.execute("SELECT #{pk} FROM #{table} WHERE #{pk} in ('#{ids.join "','"}')").collect{|x| x.first.to_s}
						insert_hashes = hashes.reject{|x| existing_ids.include? x[pk].to_s}
						update_hashes = hashes.select{|x| existing_ids.include? x[pk].to_s}
					end

					# perform the appropriate operations
					errors[table.to_sym] = []
					errors[table.to_sym] += mass_update update_hashes, into:model unless update_hashes.blank?
					errors[table.to_sym] += mass_insert insert_hashes, into:model unless insert_hashes.blank?
				end	
				return errors
			rescue Exception => e
				return {method:e} unless defined? errors
				errors[:method] = e if defined? errors
				return errors
			end
		end

		def mass_update hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				model = into.is_a?(String) ? into.classify.constantize : into
				id_column_name = model.primary_key
				created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
				updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"
				solitary_queries = []
				t = model.arel_table

				# organize by unique column sets
				unique_column_sets = {}

				hashes.each do |hash|
					column_set = hash.keys.sort
					unique_column_sets[column_set] = [] unless unique_column_sets.has_key? column_set and unique_column_sets[column_set].is_a? Array
					unique_column_sets[column_set] << hash
				end

				# assemble list of queries (1 for each unique set of columns)
				queries = []

				unique_column_sets.each do |column_set, hash_group|
					if id_column_name.is_a? Array
						ids = hash_group.collect{|hash| Hash[id_column_name.map.with_index{|column_name,i| [column_name,hash[column_name]] }]}
						update = 	"UPDATE #{model.table_name} SET "
						where_clauses = []
						id_column_name.each do |key|
							value_set = ids.collect{|id_set| ActiveRecord::Base.connection.quote(ActiveRecord::Base.connection.type_cast(id_set[key], model.column_types[key]))}
							where_clauses << "(#{model.table_name}.#{key} in (#{value_set.join ','}))"
						end
						where = "WHERE #{where_clauses.join ' and '}"

						set_fragments = {}

						hash_group.each do |hash|
							hash = convert_to_db_format hash, model:model
							if id_column_name.all?{|column_name| hash.has_key? column_name}	# if the hash has all primary keys
								hash.each do |k,v|
									unless id_column_name.include? k 	# don't allow the update of primary key columns
										set_fragments[k] = [] unless set_fragments.has_key? k and set_fragments[k].is_a? Array
										case_fragments = []
										id_column_name.each do |key|
											case_fragments << "#{ActiveRecord::Base.connection.quote_column_name key} = #{ActiveRecord::Base.connection.quote hash[key]}"
										end
										set_fragments[k] << "WHEN (#{case_fragments.join ' and '}) THEN #{ActiveRecord::Base.connection.quote v}"
									end
								end
							end
						end
					else
						ids = hash_group.collect{|x| x[id_column_name]}
						update = 	"UPDATE #{model.table_name} SET "
						where = 	"WHERE #{model.table_name}.#{id_column_name} in ('#{ids.join("','")}')"

						set_fragments = {}

						hash_group.each do |hash|
							hash = convert_to_db_format hash, model:model 	# TODO: adapt the method to work nicely with updates (ie- don't overwrite the created_at)
							if hash.has_key? id_column_name
								hash.each do |k,v|
									if k != id_column_name
										set_fragments[k] = [] unless set_fragments.has_key? k and set_fragments[k].is_a? Array
										set_fragments[k] << "WHEN #{ActiveRecord::Base.connection.quote hash[id_column_name]} THEN #{ActiveRecord::Base.connection.quote v}"
									end
								end
							end
						end
					end

					set_columns = []

					set_fragments.each do |column, values|
						set_columns << "#{column} = CASE #{model.table_name}.#{id_column_name} #{values.join ' '} END" unless id_column_name.is_a? Array
						set_columns << "#{column} = CASE #{values.join ' '} END" if id_column_name.is_a? Array
					end

					queries << "#{update} #{set_columns.join ', '} #{where}"
				end
				# [{"id"=>545, "header"=>"new system","details"=>"ya, it worked"},{"id"=>546, "header"=>"sweet system"},{"id"=>547, "header"=>"THAT system","details"=>"ya, it worked"}]
				errors = []
				# execute the queries
				queries.each do |sql|
					begin
						query sql
					rescue Exception => e
						puts e.message
						errors << e
					end
				end	
				return errors		
			rescue Exception => e
				return (defined? errors) ? (errors << e) : [e]
			end
		end

		def mass_insert_by_table json_objects, key:{}
			begin		
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = {}
				tables.each do |table|
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
					errors[table.to_sym] = mass_insert hashes, into:table
				end
				return errors
			rescue Exception => e
				return {method:e} unless defined? errors
				errors[:method] = e if defined? errors
				return errors
			end
		end

		def mass_insert hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				# create an array of single insert queries
				model = into.is_a?(String) ? into.classify.constantize : into
				id_column_name = model.primary_key
				created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
				updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"
				solitary_queries = []
				t = model.arel_table

				hashes.each do |h|
					im = Arel::InsertManager.new(ActiveRecord::Base)
					unless id_column_name.is_a? Array 	# don't modify the id fields if there are concatenated primary keys
						h.delete id_column_name if model.columns.select{|x| x.name == id_column_name}.first.extra == 'auto_increment' or h[id_column_name].blank?
					end
					h = convert_to_db_format h, model:model, created_at:created_at, updated_at:updated_at
					pairs = h.collect do |k,v|
						[t[k.to_sym],v]
					end
					im.insert pairs
					solitary_queries << im.to_sql
				end

				# group the queries by unique column lists
				concentrated_queries = {}

				solitary_queries.each do |q|
					k = q.gsub /\s*VALUES.*$/,''
					concentrated_queries[k] = [] unless concentrated_queries.has_key? k and concentrated_queries[k].is_a? Array
					concentrated_queries[k] << q.gsub(/^.*VALUES\s*/,'')
				end

				errors = []
				# reparse the queries and execute them
				concentrated_queries.each do |k,v|
					begin
						query "#{k} VALUES #{v.join(", ")}"				
					rescue Exception => e
						puts e.message
						errors << e
					end
				end
				return errors
			rescue Exception => e
				return (defined? errors) ? (errors << e) : [e]
			end
		end


		def convert_to_db_format json_object, model:nil, created_at:'created_at', updated_at:'updated_at'
			throw "No Model provided, cannot format the data for the specified columns" if model.blank?

			json_date_regex = /^"?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[\+\-]\d{2}:\d{2}"?$/i
			time = Time.now.to_s(:db)
			crud_times = [created_at,updated_at]
			json_object.each do |k,v|
				v = Time.parse v if v.is_a? String and v =~ json_date_regex												# fix funky to_json format if present
				v = time if crud_times.include? k and (v.blank? or k == updated_at) and model.column_names.include? k	# add crud time if it is blank and it is a column in the model or if it is update_at just add the time

				# convert to correct database type
				begin 
					v = ActiveRecord::Base.connection.type_cast v, model.column_types[k]
				rescue Exception => e 	# If it is a text field, automatically yamlize it if there is a non text type passed in (just like normal active record saves)
					v = ActiveRecord::Base.connection.type_cast v.to_yaml, model.column_types[k] if e.is_a? TypeError and model.column_types[k].type == :text
				end
				json_object[k] = v
			end

			return json_object
		end

		def query sql
			if database_connection.blank?
				res = ActiveRecord::Base.connection.execute sql
				ActiveRecord::Base.connection.close
			else
				res = database_connection.execute sql
			end

			return res
		end
	end

	class << self
		include Actions
	end

end
