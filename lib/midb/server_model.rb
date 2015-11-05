require 'midb/server_controller'
require 'midb/dbengine_model'
require 'midb/server_view'

require 'sqlite3'
require 'json'
require 'cgi'
module MIDB
  class ServerModel
    attr_accessor :jsf

    # Method: get_structure
    # Safely get the structure
    def self.get_structure()
      JSON.parse(IO.read("./json/#{@jsf}.json"))["id"]
    end

    # Method: query_to_hash
    # Convert a HTTP query string to a JSONable hash
    def self.query_to_hash(query)
      Hash[CGI.parse(query).map {|key,values| [key, values[0]||true]}]
    end

    # Method: post
    # Act on POST requests - create a new resource
    def self.post(db, jsf, data)
      @jsf = jsf
      jss = self.get_structure() # For referencing purposes

      input = self.query_to_hash(data)
      bad_request = false
      resp = nil
      jss.each do |key, value|
        # Check if we have it on the query too
        unless input.has_key? key
          resp = MIDB::ServerView.json_error(400, "Bad Request - Not enough data for a new resource")
          MIDB::ServerController.http_status = 400
          bad_request = true
        end
      end
      input.each do |key, value|
        # Check if we have it on the structure too
        unless jss.has_key? key
          resp = MIDB::ServerView.json_error(400, "Bad Request - Wrong argument #{key}")
          MIDB::ServerController.http_status = 400
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
            if MIDB::ServerController.config["dbengine"] == :mysql
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
        dbe = MIDB::DbengineModel.new
        dblink = dbe.connect()
        results = []
        rid = nil
        # Find the ID to return in the response (only for the first query)
        queries.each do |q|
          results.push dbe.query(dblink, q)
          if MIDB::ServerController.config["dbengine"] == :mysql
            rid ||= dbe.extract(dbe.query(dblink, "SELECT id FROM #{main_table} WHERE id=(SELECT LAST_INSERT_ID());"), "id")
          else
            rid ||= dbe.extract(dbe.query(dblink, "SELECT id FROM #{main_table} WHERE id=(last_insert_rowid());"), "id")
          end
        end
        MIDB::ServerController.http_status = "201 Created"
        resp = {"status": "201 created", "id": rid}
      end
      return resp
    end

    # Method: put
    # Update an already existing resource
    def self.put(db, jsf, id, data)
      @jsf = jsf
      jss = self.get_structure() # For referencing purposes

      input = self.query_to_hash(data)
      bad_request = false
      resp = nil
      input.each do |key, value|
        # Check if we have it on the structure too
        unless jss.has_key? key
          resp = MIDB::ServerView.json_error(400, "Bad Request - Wrong argument #{key}")
          MIDB::ServerController.http_status = 400
          bad_request = true
        end
      end

      # Check if the ID exists
      db = MIDB::DbengineModel.new
      dbc = db.connect()
      dbq = db.query(dbc, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
      unless db.length(dbq) > 0
        resp = MIDB::ServerView.json_error(404, "ID not found")
        MIDB::ServerController.http_status = 404
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
        MIDB::ServerController.http_status = "200 OK"
        resp = {"status": "200 OK"}
      end
      return resp
    end


    def self.delete(db, jsf, id)
      # Check if the ID exists
      db = MIDB::DbengineModel.new
      dbc = db.connect()
      dbq = db.query(dbc, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
      if not db.length(dbq) > 0
        resp = MIDB::ServerView.json_error(404, "ID not found").to_json
        MIDB::ServerController.http_status = 404
        bad_request = true
      else
        # ID Found, so let's delete it. (including linked resources!)
        @jsf = jsf
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
        MIDB::ServerController.http_status = "200 OK"
        resp = {"status": "200 OK"}
      end
      return resp
    end

    # Method: get_entries
    # Get the entries from a given ID.
    def self.get_entries(db, jsf, id)
      @jsf = jsf
      jso = Hash.new()

      dbe = MIDB::DbengineModel.new()
      dblink = dbe.connect()
      rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
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
            jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
          end
        end
        MIDB::ServerController.http_status = "200 OK"
      else
        MIDB::ServerController.http_status = "404 Not Found"
        jso = MIDB::ServerView.json_error(404, "Not Found")
      end
      return jso

    end

    # Method: get_all_entries
    # Get all the entries from the fields specified in a JSON-parsed hash
    def self.get_all_entries(db, jsf)
      @jsf = jsf
      jso = Hash.new()
   
      # Connect to database
      dbe = MIDB::DbengineModel.new()
      dblink = dbe.connect()
      rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]};")

      # Iterate over all rows of this table
      rows.each do |row|
        # Replace the "id" in the given JSON with the actual ID and expand it with the fields
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
          jso[row["id"]][name] = dbe.length(query) > 0 ? dbe.extract(query,field) : "unknown"
        end
      end
      return jso
    end
  end
end
