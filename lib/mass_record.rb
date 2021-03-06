require "mass_record/engine"

class Array
	def pretty_inspect
		"[\n" + join(",\n") + ']'
	end
end

module MassRecord
	mattr_accessor :path, :folder_path, :database_connection, :logger, :individual_count, :mass_count
	self.path = {}
	self.folder_path = "tmp/#{Rails.env}"
	self.path[:queries] = "tmp/#{Rails.env}"
	self.path[:queued_queries] = "tmp/#{Rails.env}"
	self.path[:errored_queries] = "tmp/#{Rails.env}"
	self.path[:completed_queries] = "tmp/#{Rails.env}"
	logger = Logger.new STDOUT

	module Actions
		include ActionView::Helpers::TextHelper
		mattr_accessor :individual_count, :mass_count
		attr_accessor :individual_count, :mass_count
		path = {}
		folder_path = "tmp/#{Rails.env}"
		path[:queries] = "#{folder_path}/queries"
		path[:queued_queries] = "#{path[:queries]}/queued"
		path[:errored_queries] = "#{path[:queries]}/errored"
		path[:completed_queries] = "#{path[:queries]}/completed"
		logger = Logger.new STDOUT
		self.individual_count = 0
		self.mass_count = 0

		class IndividualError < Exception
			attr_accessor :operation,:table,:json_object,:original_exception,:backtrace,:backtrace_locations,:cause,:exception,:message

			def initialize exception, json_object:nil, operation:nil, table:nil
				self.backtrace = exception.backtrace
				self.backtrace_locations = exception.backtrace_locations
				self.cause = exception.cause
				self.exception = exception.exception
				self.message = exception.message

				self.original_exception = exception
				self.json_object = json_object
				self.operation = operation
				self.table = table
			end

			def to_s
				original_exception.to_s
			end
		end

		def slim_data object_array, keep:[], operation: :save
			return object_array if keep.blank? unless operation.to_s == 'update' or object_array.any?{|x| !x.new_record?}
			slimmed_objects = []

			object_array.each do |object|
				model = object.class
				created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
				updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"

				# narrow the attributes to just the relevant ones
				keepers = object.attributes.select{|k,v| object.changed.include? k} if (operation.to_s == 'update' or !object.new_record?) and keep.blank?
				keepers = object.attributes.select{|k,v| keep.map(&:to_s).include? k} unless keep.blank?

				# also keep important fields primary key, and created and updated datestamps
				unless keepers.blank?
					keepers = keepers.merge(object.attributes.select{|k,v| (model.primary_key+[created_at,updated_at]).include? k}) if model.primary_key.is_a? Array
					keepers = keepers.merge(object.attributes.select{|k,v| [model.primary_key,created_at,updated_at].include? k}) unless model.primary_key.is_a? Array
				end

				slimmed_objects << keepers
			end

			return slimmed_objects
		end

		def specify_save on: nil
			return 'save' if on.blank?
			return (on.new_record? ? 'insert' : 'update') if on.is_a? ActiveRecord::Base
			return 'save'
		end

		# TODO: add logic to append the data if the filename already exists
		# accepts an array of objects with the option to specify what rails operation to perform
		def queue_for_quick_query object_array, 
			operation: :save, 
			folder:{queued:path[:queued_queries]}, 
			file_tag:Time.now.strftime("%Y%m%d%H%M%S%L").to_s,
			key:{
				table: "table",
				operation: "operation",
				object: "object"			
			},only:[]

			object_array = [object_array] unless object_array.is_a? Array
			return false if object_array.blank?
			class_array = object_array.collect{|x| x.class.name}

			object_array = slim_data(object_array, keep:only, operation:operation) if operation.to_s == 'update' or !only.blank? or object_array.any?{|x| !x.new_record?}

			queue = []

			object_array.each_with_index do |object,i|
				queue << {
					key[:table] => class_array[i], 
					key[:operation] =>  (operation.to_s.downcase == 'save') ? specify_save(on:object) : operation , 
					key[:object] => object
				} unless object.blank?
			end
			# begin
				File.open(folder[:queued]+"/#{operation.to_s}_#{file_tag}.json",'w'){|f| f.write queue.to_json} unless queue.blank?
			# rescue Exception => e
			# 	pp "#{e.message}\n#{e.backtrace[0..5].pretty_inspect}".red
			# end
		end

		def execute_queued_queries key:{
				operation:"operation", 
				table:"table", 
				object:"object"
			},synonyms:{
				insert: [:create, :new, :add, :insert, :post],
				update: [:update,:edit,:modify,:put,:patch],
				select: [:read,:select,:get],
				save:   [:save],
				delete: [:delete]
			},folder:{
				queued:path[:queued_queries],
				errored:path[:errored_queries],
				completed:path[:completed_queries]
			},file_tag:Time.now.strftime("%Y%m%d%H%M%S%L").to_s
			self.individual_count, self.mass_count, errored_objects = 0,0,[]

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
			validation_results = mass_validate json_objects
			logger.debug "#{validation_results[:passed_orders].count} valid objects of #{json_objects.count} total objects".black.on_white
			json_objects = validation_results[:passed_orders]

			# get all operations and tables in use
			operations = json_objects.collect{|x| x[key[:operation]].to_sym}.to_set.to_a
			logger.debug "Operations: #{operations.pretty_inspect}".black.on_white rescue logger.debug "Error logging operations"

			# construct mass queries
			errors = {}
			operations.each do |op|
				if synonyms[:insert].include? op
					errors[:insert] = mass_insert_by_table json_objects.select{|x| synonyms[:insert].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:update].include? op
					errors[:update] = mass_update_by_table json_objects.select{|x| synonyms[:update].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:save].include? op	# needs to intelligently determine if the order already exists, insert if not, update if so
					errors[:save] = mass_save_by_table json_objects.select{|x| :save == x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:delete].include? op
				elsif synonyms[:select].include? op
				else
				end
			end

			# Collect mass errors and the associated objects
			errors_present = errors.any?{|op,tables| tables.has_key? :run_time or tables.any?{|table,col_sets| !col_sets.blank?}}
			errored_objects = collect_errored_objects found_in:errors, from:json_objects, key:key, synonyms:synonyms if errors_present

			# Retry objects from the failed queries on an individual query basis
			individual_errors = errors_present ? (query_per_object errored_objects, key:key, synonyms:synonyms) : []

			# Collect individual errors and their associated objects with the option for custom handling
			individually_errored_objects = collect_individually_errored_objects from:errored_objects, based_on:individual_errors, key:key
			individual_errors += (collect_run_time_errors found_in:errors) + validation_results[:failed_orders]
			default_error_handling = handle_individual_errors_callback errors:individual_errors, errored_objects:individually_errored_objects, all_objects:json_objects

			# Save failed objects, archive all objects, and log out a summary
			if default_error_handling 
				# Save a new file with just the errored objects in the errored folder 
				# (which will be all the objects if there is not a 1 to 1 ratio between the errors and errored objects)
				# THEN save a new file with ALL the objects in the completed folder
				if json_objects.count > 0
					if individual_errors.count == individually_errored_objects.count
						File.open("#{folder[:errored]}/errored_only_#{file_tag}.json",'w'){|f| f.write individually_errored_objects.to_json} if individual_errors.count > 0
						File.open("#{folder[:completed]}/#{file_tag}.json",'w'){|f| f.write json_objects.to_json}
					else
						File.open("#{folder[:errored]}/all_#{file_tag}.json",'w'){|f| f.write json_objects.to_json}
					end
				end

				# Delete all the original files
				file_names = files.collect{|x| "#{folder[:queued]}/#{x}.processing"}
				File.delete(*file_names)

				# Log out a summary of what happened
				logger.info "\nProcessed #{pluralize((json_objects.count),'object')} with #{pluralize((individual_errors.count),'error')}".black.on_white
				logger.info "\tMass Queries:\t\t#{self.mass_count} for #{pluralize((json_objects.count - errored_objects.count),'object')}\n\tRecovery Queries:\t#{self.individual_count} for #{pluralize(errored_objects.count,'object')}\n\tErrors:\t\t\t#{individual_errors.count}".black.on_white if individual_errors.count > 0 or logger.debug?
				individual_errors.each_with_index{|x,i| logger.info "\t\t(#{i}) #{x.to_s[0..90]}...".black.on_white} if individual_errors.count > 0 or logger.debug?
			end
			return individual_errors
		end

		def handle_individual_errors_callback errors:[], errored_objects:[], all_objects:[]
			# TODO: must be manually overidden.  Assumes a true return value means to use the engines default error handling and logging, and a false return value means to skip all subsequent actions
			return true
		end

		# always returns the name of the table (String) regardless of whether the name is passed in or if the model is passed in
		def get_table_name table
			if table.is_a? String
				return table
			elsif table.methods.include? :name
				return table.name
			end
			return table
		end

		def collect_individually_errored_objects from:[], based_on:[], key:{}
			individuals = []
			based_on.each do |error|
				if error.is_a? IndividualError and !error.json_object.blank?
					errored_object = from.select{|object| object[key[:table]] === get_table_name(error.table) and ['save',error.operation].include?(object[key[:operation]]) and object[key[:object]] === error.json_object }.first
					individuals << errored_object unless errored_object.blank? 
				end
			end
			return individuals
		end

		def collect_run_time_errors found_in:{}, loop_limit:10
			return [] if found_in.blank?
			run_time_errors = []

			while found_in.is_a? Hash and loop_limit > 0
				loop_limit -= 1
				found_in.each do |k,v|
					if k == :run_time
						run_time_errors << v
					else 
						run_time_errors += collect_run_time_errors found_in:v, loop_limit:loop_limit
					end
				end
			end
			return run_time_errors
		end

		def collect_errored_objects found_in:{}, from:[], key:{}, synonyms:{}
			return [] if found_in.blank? or from.blank?

			errored_objects = []

			found_in.each do |operation, tables|
				unless operation == :run_time
					tables.each do |table, column_sets|
						unless table == :run_time
							column_sets.each do |column_set,error|
								unless column_set == :run_time
									if error.is_a? Exception and error.is_a? ActiveRecord::StatementInvalid
										# collect objects by operation, table, and column set
										operation_terms = synonyms[operation.to_sym]
										errored_objects += from.select{|x| table.to_s == x[key[:table]].to_s and operation_terms.include? x[key[:operation]].to_sym and x[key[:object]].keys.sort == column_set.sort}
									end
								end
							end
						end
					end
				end
			end

			return errored_objects
		end

		def query_per_object objects, key:{}, synonyms:{}
			logger.info "Executing #{objects.count} individual queries...".black.on_white
			# get all operations and tables in use
			operations = objects.collect{|x| x[key[:operation]].to_sym}.to_set.to_a

			# construct queries
			errors = []
			operations.each do |op|
				if synonyms[:insert].include? op
					errors += insert_by_table objects.select{|x| synonyms[:insert].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:update].include? op
					errors += update_by_table objects.select{|x| synonyms[:update].include? x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:save].include? op	# needs to intelligently determine if the order already exists, insert if not, update if so
					errors += save_by_table objects.select{|x| :save == x[key[:operation]].to_sym.downcase}, key:key
				elsif synonyms[:delete].include? op
				elsif synonyms[:select].include? op
				else
				end
			end
			return errors
		end

		def update_by_table json_objects, key:{}
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = []
				tables.each do |table|
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
					errors += update hashes, into:table
				end
				return errors
			rescue Exception => e
				return ((defined? errors) ? (errors << IndividualError.new(e,operation:"update")) : [IndividualError.new(e,operation:"update")])
			end
		end

		def sort_save_operations from:nil, for_table:nil, key:{}
			return {} if from.blank? or for_table.blank?
			table = for_table
			hashes = from.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
			model = get_model from:for_table
			connection = model.connection
			pk = model.primary_key

			# organize hashes based on whether they exist (based on their primary key(s)) in the table or not
			if pk.is_a? Array
				ids = hashes.reject{|x| pk.any?{|k| x[k].blank?}}.collect{|x| x.select{|k,v| pk.include? k}}	# only accept full sets of pk's
				where_clauses = []
				ids.each do |id|
					equivalence_clauses = []
					id.each do |k,v|
						equivalence_clauses << "#{k} = #{connection.quote(connection.type_cast(v, model.column_types[k]))}"
					end
					where_clauses << "(#{equivalence_clauses.join ' and '})"
				end
				existing_id_sets = model.find_by_sql("SELECT #{pk.join ', '} FROM #{model.table_name} WHERE #{where_clauses.join ' OR '}").collect{|x| x.attributes}  #.collect{|x| Hash[x.map.with_index{|x,i| [pk[i],x]}]}
				insert_hashes = hashes.reject{|h| existing_id_sets.any?{|set| h == h.merge(set)}}
				update_hashes = hashes.select{|h| existing_id_sets.any?{|set| h == h.merge(set)}}
			else
				ids = hashes.reject{|x| x[pk].blank?}.collect{|x| x[pk]}	# should not include null values
				existing_ids = model.find_by_sql("SELECT #{pk} FROM #{model.table_name} WHERE #{pk} in ('#{ids.join "','"}')").collect{|x| x[pk]}	# for some reason model.connection.execute returns the count
				insert_hashes = hashes.reject{|x| existing_ids.include? x[pk].to_s}
				update_hashes = hashes.select{|x| existing_ids.include? x[pk].to_s}
			end

			return {insert:insert_hashes,update:update_hashes}
		end

		def save_by_table json_objects, key:{}			
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = []
				tables.each do |table|
					# sort the hashes by operation type
					sorted_hashes = sort_save_operations from:json_objects, for_table:table, key:key

					# perform the appropriate operations
					model = get_model from:table
					errors += update sorted_hashes[:update], into:model unless sorted_hashes[:update].blank?
					errors += insert sorted_hashes[:insert], into:model unless sorted_hashes[:insert].blank?
				end	
				return errors
			rescue Exception => e
				return ((defined? errors) ? (errors << IndividualError.new(e,operation:"save")) : [IndividualError.new(e,operation:"save")])
			end
		end

		def insert_by_table json_objects, key:{}
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = []
				tables.each do |table|
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}
					errors += insert hashes, into:table
				end
				return errors
			rescue Exception => e
				return ((defined? errors) ? (errors << IndividualError.new(e,operation:"insert")) : [IndividualError.new(e,operation:"insert")])
			end
		end

		def get_model from:nil
			return from if from.is_a? Class
			if from.is_a? String
				model = from.constantize rescue nil
				model = from.classify.constantize rescue nil if model.blank?
				return model
			end
			return nil
		end

		def sql_for_insert hash, into:nil
			return nil if hash.blank? or into.blank?
			model = get_model from:into
			id_column_name = model.primary_key
			created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
			updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"
			t = model.arel_table

			h = hash.clone	# use a copy of hash, so it doesn't change the original data

			# assemble an individual query
			# im = Arel::InsertManager.new(ActiveRecord::Base)
			im = Arel::InsertManager.new(model)
			unless id_column_name.is_a? Array 	# don't modify the id fields if there are concatenated primary keys
				database_column = model.columns.select{|x| x.name == id_column_name}.first
				h.delete id_column_name if h[id_column_name].blank? or (database_column.methods.include? :extra and database_column.extra == 'auto_increment')
			end
			h = convert_to_db_format h, model:model, created_at:created_at, updated_at:updated_at
			pairs = h.collect do |k,v|
				[t[k.to_sym],v]
			end
			im.insert pairs
			im.to_sql
		end

		def sql_for_update hash, into:nil
			return nil if hash.blank? or into.blank?
			model = get_model from:into
			id_column_name = model.primary_key
			created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
			updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"
			t = model.arel_table

			h = hash.clone	# use a copy of hash, so it doesn't change the original data
			h = convert_to_db_format h, model:model, created_at:created_at, updated_at:updated_at

			# assemble an individual query
			# um = Arel::UpdateManager.new(ActiveRecord::Base)
			um = Arel::UpdateManager.new(model)
			um.where(t[id_column_name.to_sym].eq(h[id_column_name])) unless id_column_name.is_a? Array
			id_column_name.each{|key| um.where t[key.to_sym].eq(h[key])} if id_column_name.is_a? Array
			um.table(t)
			id_column_name.each{|name| h.delete name} if id_column_name.is_a? Array 	# don't allow modification of the primary keys
			h.delete id_column_name if id_column_name.is_a? String						# don't allow modification of the primary keys
			pairs = h.collect do |k,v|
				[t[k.to_sym],v]
			end
			um.set pairs
			um.to_sql
		end

		def update hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				logger.debug "Update #{into.to_s}>".black.on_white
				hashes = [hashes] unless hashes.is_a? Array
				model = get_model from:into

				errors = []
				# create an array of single insert queries
				hashes.each do |hash|
					sql = sql_for_insert hash, into:model
	
					begin
						query sql, connection:model
						logger << ".".black.on_white if logger.debug?
						self.individual_count += 1
					rescue Exception => e
						logger.debug e.message
						logger.info e.message.to_s[0..1000]
						errors << IndividualError.new(e,table:into,operation:"update",json_object:hash)
					end
				end
				return errors
			rescue Exception => e
				return (defined? errors) ? (errors << IndividualError.new(e, table:into, operation:"update")) : [IndividualError.new( e, table:into, operation:"update")]
			end
		end

		def insert hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				logger.debug "Insert #{into.to_s}>".black.on_white
				hashes = [hashes] unless hashes.is_a? Array
				model = get_model from:into

				errors = []
				# create an array of single insert queries
				hashes.each do |hash|
					sql = sql_for_insert hash, into:model
					begin
						query sql, connection:model
						self.individual_count += 1
						logger << ".".black.on_white if logger.debug?
					rescue Exception => e
						logger.debug e.message
						logger << 'E'.black.on_white if logger.info?
						errors << IndividualError.new(e,table:into,operation:"insert",json_object:hash)
					end
				end
				return errors
			rescue Exception => e
				return (defined? errors) ? (errors << IndividualError.new(e, table:into, operation:"insert")) : [IndividualError.new( e, table:into, operation:"insert")]
			end
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
					# logger.info "Table: #{table}".black.on_white
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}

					errors[table.to_sym] = {} unless errors[table.to_sym].is_a? Hash
					errors[table.to_sym].merge! mass_update hashes, into:table
				end
				return errors
			rescue Exception => e
				return {run_time:e} unless defined? errors
				errors[:run_time] = e if defined? errors
				return errors
			end
		end

		def mass_save_by_table json_objects, key:{}
			begin
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = {}
				tables.each do |table|
					# logger.info "Table: #{table}".black.on_white
					# sort the hashes by operation type
					sorted_hashes = sort_save_operations from:json_objects, for_table:table, key:key

					# perform the appropriate operations
					model = get_model from:table
					errors[table.to_sym] = {}
					errors[table.to_sym].merge! mass_update sorted_hashes[:update], into:model unless sorted_hashes[:update].blank?
					errors[table.to_sym].merge! mass_insert sorted_hashes[:insert], into:model unless sorted_hashes[:insert].blank?
				end
				return errors
			rescue Exception => e
				return {run_time:e} unless defined? errors
				errors[:run_time] = e if defined? errors
				return errors
			end
		end

		def mass_update hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				model = get_model from:into
				id_column_name = model.primary_key
				created_at = model.attribute_alias?("created_at") ? model.attribute_alias("created_at") : "created_at"
				updated_at = model.attribute_alias?("updated_at") ? model.attribute_alias("updated_at") : "updated_at"
				solitary_queries = []	# I think this can be deleted
				t = model.arel_table	# I think this can be deleted

				# organize by unique column sets
				unique_column_sets = {}

				hashes.each do |hash|
					column_set = hash.keys.sort
					unique_column_sets[column_set] = [] unless unique_column_sets.has_key? column_set and unique_column_sets[column_set].is_a? Array
					unique_column_sets[column_set] << hash
				end

				# assemble and execute queries (1 for each unique set of columns)
				queries = []
				errors = {}
				unique_column_sets.each do |column_set, hash_group|
					if id_column_name.is_a? Array
						ids = hash_group.collect{|hash| Hash[id_column_name.map.with_index{|column_name,i| [column_name,hash[column_name]] }]}
						update = 	"UPDATE #{model.table_name} SET "
						where_clauses = []
						id_column_name.each do |key|
							value_set = ids.collect{|id_set| model.connection.quote(model.connection.type_cast(id_set[key], model.column_types[key]))}
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
											case_fragments << "#{model.connection.quote_column_name key} = #{model.connection.quote hash[key]}"
										end
										set_fragments[k] << "WHEN (#{case_fragments.join ' and '}) THEN #{model.connection.quote v}"
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
										set_fragments[k] << "WHEN #{model.connection.quote hash[id_column_name]} THEN #{model.connection.quote v}"
									end
								end
							end
						end
					end

					set_columns = []

					set_fragments.each do |column, values|
						set_columns << "#{column} = CASE #{model.table_name}.#{id_column_name} #{values.join ' ' } WHEN 'findabetterwaytodothis' THEN '0' END" unless id_column_name.is_a? Array 	#TODO: ugly hack, find a better solution
						set_columns << "#{column} = CASE #{values.join ' '} WHEN 1=0 THEN '0' END" if id_column_name.is_a? Array
					end

					begin
						query "#{update} #{set_columns.join ', '} #{where}", connection:model
						self.mass_count += 1
					rescue Exception => e
						logger.debug e.message
						logger.info e.message.to_s[0..1000]
						errors[column_set] = e
					end
				end

				return errors		
			rescue Exception => e
				return (defined? errors) ? (errors.merge!({run_time:e})) : {run_time:e}
			end
		end


		def mass_insert_by_table json_objects, key:{}
			begin		
				tables = json_objects.collect{|x| x[key[:table]]}.to_set.to_a

				errors = {}
				tables.each do |table|
					# logger.info "Table: #{table}".black.on_white
					hashes = json_objects.select{|o| o[key[:table]] == table}.collect{|x| x[key[:object]]}

					errors[table.to_sym] = {} unless errors[table.to_sym].is_a? Hash
					errors[table.to_sym].merge! mass_insert hashes, into:table
				end
				return errors
			rescue Exception => e
				return {run_time:e} unless defined? errors
				errors[:run_time] = e if defined? errors
				return errors
			end
		end

		def mass_insert hashes, into:nil
			begin
				return false if hashes.blank? or into.blank?

				# create an array of single insert queries
				model = get_model from:into
				concentrated_queries = {}

				logger.debug "#{into}: Parsing #{hashes.count} hashes into a single query>".black.on_white
				hashes.each do |hash|
					logger << ".".black.on_white if logger.debug?
					original_key_set = hash.keys.sort
					sql = sql_for_insert hash, into:model

					# group the queries by unique column lists
					into_clause = sql.gsub /\s*VALUES.*$/,''
					value_clause = sql.gsub(/^.*VALUES\s*/,'')
					
					concentrated_queries[original_key_set] = {} unless concentrated_queries[original_key_set].is_a? Hash
					concentrated_queries[original_key_set][:into] = into_clause
					concentrated_queries[original_key_set][:values] = [] unless concentrated_queries[original_key_set][:values].is_a? Array
					concentrated_queries[original_key_set][:values] << value_clause
				end

				errors = {}

				# reparse the queries and execute them
				concentrated_queries.each do |column_set,clauses|
					final_query = "#{clauses[:into]} VALUES #{clauses[:values].join(", ")}"
					begin
						# puts "press enter to continue...:"	if Rails.env = 'development' and defined?(Rails::Console) and logger.debug?
						# gets								if Rails.env = 'development' and defined?(Rails::Console) and logger.debug?
						query final_query, connection:model
						self.mass_count += 1
					rescue Exception => e
						logger.debug e.message
						logger.info e.message.to_s[0..1000]
						errors[column_set] = e
					end
				end
				return errors
			rescue Exception => e
				logger.error e.message
				return (defined? errors) ? (errors.merge!({run_time:e})) : {run_time:e}
			end
		end


		def convert_to_db_format json_object, model:nil, created_at:'created_at', updated_at:'updated_at'
			throw "No Model provided, cannot format the data for the specified columns" if model.blank?

			time = Time.now.to_s(:db)
			crud_times = [created_at,updated_at]
			json_object.each do |k,v|
				v = Time.parse v if v.is_a? String and [:datetime, :date, :time, :timestamp].include? model.column_types[k].type.to_sym.downcase		# fix funky to_json format if present
				v = time if crud_times.include? k and (v.blank? or k == updated_at) and model.column_names.include? k									# add crud time if it is blank and it is a column in the model or if it is update_at just add the time
				# convert to correct database type
				begin 
					v = model.connection.type_cast v, model.column_types[k]
					# handles a bug in the activerecord-sqlserver-adapter gem version 4.1
					v = (v=='f' ? 0 : 1) if model.column_types[k].sql_type == 'bit' and ['f','t'].include?(v.to_s.downcase)
					v = model.connection.quote_string v if v.is_a? String
				rescue Exception => e 	# If it is a text field, automatically yamlize it if there is a non text type passed in (just like normal active record saves)
					v = model.connection.type_cast v.to_yaml, model.column_types[k] if e.is_a? TypeError and model.column_types[k].type == :text
				end
				json_object[k] = v
			end

			#TODO: handle if updated_at field is not present in the hash, but is in the model (so that all transactions have an accurate updated_at)

			return json_object
		end

		def query sql, connection:database_connection
			sql = sql.gsub /`(.*?)`/,'\1'														# some queries don't like the "`"s
			if connection.blank?																# a blank value was passed in or the cached connection is empty
				res = ActiveRecord::Base.connection.execute sql
				ActiveRecord::Base.connection.close
			elsif connection.is_a? Class and connection.ancestors.include? ActiveRecord::Base 	# an ActiveRecord Class was passed in
				connection.connection.execute sql
				connection.connection.close
			else
				res = connection.execute sql
			end

			return res
		end
	end

	class << self
		include Actions
	end

end
