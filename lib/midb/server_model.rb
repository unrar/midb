require 'midb/server_controller'
require 'midb/dbengine_model'
require 'midb/server_view'
require 'midb/hooks'

require 'sqlite3'
require 'json'
require 'cgi'
module MIDB
  module API
    class Model

      attr_accessor :jsf, :db, :engine, :hooks

      # Constructor
      #
      # @param jsf [String] JSON file with the schema
      # @param db [String] Database to operate on.
      # @param engine [Object] Reference to the API engine.
      #
      # @notice that @hooks (the hooks) are taken from the engine.
      def initialize(jsf, db, engine)
        @jsf = jsf
        @db = db
        @engine = engine
        @hooks = engine.hooks
      end

      # Safely get the structure
      def get_structure()
        JSON.parse(IO.read("./json/#{@jsf}.json"))["id"]
      end

      # Convert a HTTP query string to a JSONable hash
      #
      # @param query [String] HTTP query string
      def query_to_hash(query)
        Hash[CGI.parse(query).map {|key,values| [key, values[0]||true]}]
      end

      # Act on POST requests - create a new resource
      #
      # @param data [String] The HTTP query string containing what to POST.
      def post(data)
        jss = self.get_structure() # For referencing purposes

        input = self.query_to_hash(data)
        bad_request = false
        resp = nil
        jss.each do |key, value|
          # Check if we have it on the query too
          unless input.has_key? key
            resp = MIDB::Interface::Server.json_error(400, "Bad Request - Not enough data for a new resource")
            @engine.http_status = 400
            bad_request = true
          end
        end
        input.each do |key, value|
          # Check if we have it on the structure too
          unless jss.has_key? key
            resp = MIDB::Interface::Server.json_error(400, "Bad Request - Wrong argument #{key}")
            @engine.http_status = 400
            bad_request = true
          end
        end
        

        # Insert the values if we have a good request
        unless bad_request
          fields = Hash.new
          inserts = Hash.new
          main_table = self.get_structure.values[0].split('/')[0]
          input.each do |key, value|
            struct = jss[key]
            table = struct.split("/")[0]
            inserts[table] ||= []
            fields[table] ||= []
            inserts[table].push "\"" + value + "\""
            fields[table].push struct.split("/")[1]
            if struct.split("/").length > 2
              match = struct.split("/")[2]
              matching_field = match.split("->")[0]
              row_field = match.split("->")[1]
              fields[table].push matching_field
              if @engine.config["dbengine"] == :mysql
                inserts[table].push "(SELECT #{row_field} FROM #{main_table} WHERE id=(SELECT LAST_INSERT_ID()))"
              else
                inserts[table].push "(SELECT #{row_field} FROM #{main_table} WHERE id=(last_insert_rowid()))"
              end
            end
          end
          queries = []      
          inserts.each do |table, values|
            queries.push "INSERT INTO #{table}(#{fields[table].join(',')}) VALUES (#{inserts[table].join(',')});"
          end
          # Connect to the database
          dbe = MIDB::API::Dbengine.new(@engine.config, @db)
          dblink = dbe.connect()
          results = []
          rid = nil
          # Find the ID to return in the response (only for the first query)
          queries.each do |q|
            results.push dbe.query(dblink, q)
            if @engine.config["dbengine"] == :mysql
              rid ||= dbe.extract(dbe.query(dblink, "SELECT id FROM #{main_table} WHERE id=(SELECT LAST_INSERT_ID());"), "id")
            else
              rid ||= dbe.extract(dbe.query(dblink, "SELECT id FROM #{main_table} WHERE id=(last_insert_rowid());"), "id")
            end
          end
          @engine.http_status = "201 Created"
          resp = {status: "201 created", id: rid}
        end
        return resp
      end

      # Update an already existing resource
      #
      # @param id [Fixnum] ID to alter
      # @param data [String] HTTP query string
      def put(id, data)
        jss = self.get_structure() # For referencing purposes

        input = self.query_to_hash(data)
        bad_request = false
        resp = nil
        input.each do |key, value|
          # Check if we have it on the structure too
          unless jss.has_key? key
            resp = MIDB::Interface::Server.json_error(400, "Bad Request - Wrong argument #{key}")
            @engine.http_status = 400
            bad_request = true
          end
        end

        # Check if the ID exists
        db = MIDB::API::Dbengine.new(@engine.config, @db)
        dbc = db.connect()
        dbq = db.query(dbc, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
        unless db.length(dbq) > 0
          resp = MIDB::Interface::Server.json_error(404, "ID not found")
          @engine.http_status = 404
          bad_request = true
        end
        
        # Update the values if we have a good request
        unless bad_request
          fields = Hash.new
          inserts = Hash.new
          where_clause = Hash.new
          main_table = self.get_structure.values[0].split('/')[0]
          where_clause[main_table] = "id=#{id}"
          input.each do |key, value|
            struct = jss[key]
            table = struct.split("/")[0]
            inserts[table] ||= []
            fields[table] ||= []
            inserts[table].push "\"" + value + "\""
            fields[table].push struct.split("/")[1]
            if struct.split("/").length > 2
              match = struct.split("/")[2]
              matching_field = match.split("->")[0]
              row_field = match.split("->")[1]
              where_clause[table] = "#{matching_field}=(SELECT #{row_field} FROM #{main_table} WHERE #{where_clause[main_table]});"
            end
          end
          queries = []
          updates = Hash.new
          # Turn it into a hash
          inserts.each do |table, values|
            updates[table] ||= Hash.new
            updates[table] = Hash[fields[table].zip(inserts[table])]
            query = "UPDATE #{table} SET "
            updates[table].each do |f, v|
              query = query + "#{f}=#{v} "
            end
            queries.push query + "WHERE #{where_clause[table]};"
          end
          # Run the queries
          results = []
          queries.each do |q|
            results.push db.query(dbc, q)
          end
          @engine.http_status = "200 OK"
          resp = {status: "200 OK"}
        end
        return resp
      end

      # Delete a resource
      #
      # @param id [Fixnum] ID to delete
      def delete(id)
        # Check if the ID exists
        db = MIDB::API::Dbengine.new(@engine.config, @db)
        dbc = db.connect()
        dbq = db.query(dbc, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
        if not db.length(dbq) > 0
          resp = MIDB::Interface::Server.json_error(404, "ID not found").to_json
          @engine.http_status = 404
          bad_request = true
        else
          # ID Found, so let's delete it. (including linked resources!)
          jss = self.get_structure() # Referencing

          where_clause = {}
          tables = []
          main_table = jss.values[0].split('/')[0]
          where_clause[main_table] = "id=#{id}"

          jss.each do |k, v|
            table = v.split("/")[0]
            tables.push table unless tables.include? table
            # Check if it's a linked resource, generate WHERE clause accordingly
            if v.split("/").length > 2
              match = v.split("/")[2]
              matching_field = match.split("->")[0]
              row_field = match.split("->")[1]
              # We have to run the subquery now because it'll be deleted later!
              subq = "SELECT #{row_field} FROM #{main_table} WHERE #{where_clause[main_table]};"
              res = db.query(dbc, subq)
              subqres = db.extract(res, row_field)
              where_clause[table] ||= "#{matching_field}=#{subqres}"
            else
              # Normal WHERE clause
              where_clause[table] ||= "id=#{id}"
            end
          end

          # Generate and run queries
          results = []
          tables.each do |tb|
            query = "DELETE FROM #{tb} WHERE #{where_clause[tb]};"
            results.push db.query(dbc, query)
          end
          @engine.http_status = "200 OK"
          resp = {status: "200 OK"}
        end
        return resp
      end

      # Get an entry with a given id.
      #
      # @param id [Fixnum] ID of the entry
      def get_entries(id)
        jso = Hash.new()

        dbe = MIDB::API::Dbengine.new(@engine.config, @db)
        dblink = dbe.connect()
        rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
        if rows == false
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
        if dbe.length(rows) > 0
          rows.each do |row|
            jso[row["id"]] = self.get_structure
            self.get_structure.each do |name, dbi|
              table = dbi.split("/")[0]
              field = dbi.split("/")[1]
              # Must-match relations ("table2/field/table2-field->row-field")
              if dbi.split("/").length > 2
                match = dbi.split("/")[2]
                matching_field = match.split("->")[0]
                row_field = match.split("->")[1]
                query = dbe.query(dblink, "SELECT #{field} FROM #{table} WHERE #{matching_field}=#{row[row_field]};")
              else
                query = dbe.query(dblink, "SELECT #{field} from #{table} WHERE id=#{row['id']};")
              end
              if query == false
                return MIDB::Interface::Server.json_error(400, "Bad Request")
              end
              jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
              jso[row["id"]][name] = @hooks.format_field(name, jso[row["id"]][name])
            end
          end
          @engine.http_status = "200 OK"
        else
          @engine.http_status = "404 Not Found"
          jso = MIDB::Interface::Server.json_error(404, "Not Found")
        end
        return jso

      end

      # Get all the entries from the database
      def get_all_entries()
        jso = Hash.new()
     
        # Connect to database
        dbe = MIDB::API::Dbengine.new(@engine.config, @db)
        dblink = dbe.connect()
        rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]};")
        if rows == false
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
        # Iterate over all rows of this table
        rows.each do |row|
          jso[row["id"]] = self.get_structure
          self.get_structure.each do |name, dbi|
            table = dbi.split("/")[0]
            field = dbi.split("/")[1]
            # Must-match relations ("table2/field/table2-field->row-field")
            if dbi.split("/").length > 2
              match = dbi.split("/")[2]
              matching_field = match.split("->")[0]
              row_field = match.split("->")[1]
              query = dbe.query(dblink, "SELECT #{field} FROM #{table} WHERE #{matching_field}=#{row[row_field]};")
            else
              query = dbe.query(dblink, "SELECT #{field} from #{table} WHERE id=#{row['id']};")
            end
            if query == false
              return MIDB::Interface::Server.json_error(400, "Bad Request")
            end
            jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
            jso[row["id"]][name] = @hooks.format_field(name, jso[row["id"]][name])
          end
        end
        @hooks.after_get_all_entries(dbe.length(rows))
        return jso
      end


      # Get all the entries from the database belonging to a column
      def get_column_entries(column)
        jso = Hash.new() 
        jss = self.get_structure()
        db_column = nil
        # Is the column recognized?
        if jss.has_key? column then
          db_column = jss[column].split("/")[1]
        else
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
  
        # Connect to database
        dbe = MIDB::API::Dbengine.new(@engine.config, @db)
        dblink = dbe.connect()
        rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]};")
        if rows == false
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
        # Iterate over all rows of this table
        rows.each do |row|

          name = column
          dbi = jss[name]
          table = dbi.split("/")[0]
          field = dbi.split("/")[1]
          # Must-match relations ("table2/field/table2-field->row-field")
          if dbi.split("/").length > 2
            match = dbi.split("/")[2]
            matching_field = match.split("->")[0]
            row_field = match.split("->")[1]
            query = dbe.query(dblink, "SELECT #{field} FROM #{table} WHERE #{matching_field}=#{row[row_field]};")
          else
            query = dbe.query(dblink, "SELECT #{field} from #{table} WHERE id=#{row['id']};")
          end
          if query == false
            return MIDB::Interface::Server.json_error(400, "Bad Request")
          end
          jso[row["id"]] = {}
          jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
          jso[row["id"]][name] = @hooks.format_field(name, jso[row["id"]][name])
        end
        @hooks.after_get_all_entries(dbe.length(rows))
        return jso
      end

      # Get all the entries from the database belonging to a column matching a pattern
      def get_matching_rows(column, pattern)
        jso = Hash.new() 
        jss = self.get_structure()
        db_column = nil
        # Is the column recognized?
        if jss.has_key? column then
          db_column = jss[column].split("/")[1]
        else
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
  
        # Connect to database
        dbe = MIDB::API::Dbengine.new(@engine.config, @db)
        dblink = dbe.connect()
        rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]};")
        if rows == false
          return MIDB::Interface::Server.json_error(400, "Bad Request")
        end
        # Iterate over all rows of this table
        rows.each do |row|
          # Does this row match?
          bufd = jss[column]
          b_table = bufd.split("/")[0]
          b_field = bufd.split("/")[1]
          # The column is in another table, let's find it
          if bufd.split("/").length > 2    
            b_match = bufd.split("/")[2]
            b_m_field = b_match.split("->")[0]
            b_r_field = b_match.split("->")[1]

            bquery = dbe.query(dblink, "SELECT #{b_field} FROM #{b_table} WHERE (#{b_m_field}=#{row[b_r_field]} AND #{db_column} LIKE '%#{pattern}%');")
          else
            # It's in the same main table, let's see if it matches
            bquery = dbe.query(dblink, "SELECT #{b_field} FROM #{b_table} WHERE (id=#{row['id']} AND #{db_column} LIKE '%#{pattern}%');")
          end

          # Unless the query has been successful (thus this row matches), skip to the next row
          unless dbe.length(bquery) > 0
            next
          end

          jso[row["id"]] = self.get_structure

          self.get_structure.each do |name, dbi|
            table = dbi.split("/")[0]
            field = dbi.split("/")[1]
            # Must-match relations ("table2/field/table2-field->row-field")
            if dbi.split("/").length > 2
              match = dbi.split("/")[2]
              matching_field = match.split("->")[0]
              row_field = match.split("->")[1]
              query = dbe.query(dblink, "SELECT #{field} FROM #{table} WHERE #{matching_field}=#{row[row_field]};")
            else
              query = dbe.query(dblink, "SELECT #{field} from #{table} WHERE id=#{row['id']};")
            end
            if query == false
              next
            end
            jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
            jso[row["id"]][name] = @hooks.format_field(name, jso[row["id"]][name])
          end
        end
        @hooks.after_get_all_entries(dbe.length(rows))
        return jso
      end
    end
  end
end
