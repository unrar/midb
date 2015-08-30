require './app/controllers/server_controller'
require './app/models/dbengine'
require './app/views/server'

require 'sqlite3'
require 'json'
require 'cgi'

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
        resp = ServerView.json_error(400, "Bad Request - Not enough data for a new resource")
        ServerController.http_status = 400
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
          if ServerController.config["dbengine"] == "mysql"
            inserts[table].push "(SELECT #{row_field} FROM #{main_table} WHERE id=(SELECT LAST_INSERT_ID()))"
          else
            inserts[table].push "(SELECT #{row_field} FROM #{main_table} WHERE id=(last_insert_rowid()))"
          end
        end
      end
      queries = []
      inserts.each do |table, values|
        puts fields[table].join(",")
        puts inserts[table].join(",")
        queries.push "INSERT INTO #{table}(#{fields[table].join(',')}) VALUES (#{inserts[table].join(',')});"
      end
      # Connect to the database
      dbe = DbengineModel.new
      dblink = dbe.connect()
      results = []
      queries.each do |q|
        results.push dbe.query(dblink, q)
      end
      ServerController.http_status = "201 Created"
      resp = {"status": "201 created"}
    end
    return resp
  end

  def self.put(db, jsf, id, data)
    jo = {"data" => data, "id" => id}
    return jo
  end
  def self.delete(db, jsf, id)
    jo = {"id" => id}
  end
  # Method: get_entries
  # Get the entries from a given ID.
  def self.get_entries(db, jsf, id)
    @jsf = jsf
    jso = Hash.new()

    dbe = DbengineModel.new()
    dblink = dbe.connect()
    rows = dbe.query(dblink, "SELECT * FROM #{self.get_structure.values[0].split('/')[0]} WHERE id=#{id};")
    if rows.length > 0
      rows.each do |row|
        jso[row["id"]] = self.get_structure

        self.get_structure.each do |name, dbi|
          puts dbi
          table = dbi.split("/")[0]
          field = dbi.split("/")[1]
          # Must-match relations ("table2/field/table2-field->row-field")
          if dbi.split("/").length > 2
            match = dbi.split("/")[2]
            matching_field = match.split("->")[0]
            row_field = match.split("->")[1]
            puts match, matching_field, row_field, row[row_field]
            query = dbe.query(dblink, "SELECT #{field} FROM #{table} WHERE #{matching_field}=#{row[row_field]};")
          else
            query = dbe.query(dblink, "SELECT #{field} from #{table} WHERE id=#{row['id']};")
          end
          jso[row["id"]][name] = query.length > 0 ? dbe.extract(query,field) : "unknown"
        end
      end
      ServerController.http_status = "200 OK"
    else
      ServerController.http_status = "404 Not Found"
      jso = ServerView.json_error(404, "Not Found")
    end
    return jso

  end

  # Method: get_all_entries
  # Get all the entries from the fields specified in a JSON-parsed hash
  def self.get_all_entries(db, jsf)
    @jsf = jsf
    jso = Hash.new()
 
    # Connect to database
    dbe = DbengineModel.new()
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
        jso[row["id"]][name] = dbe.extract(query,field)
      end
    end
    return jso
  end
end
