require './app/controllers/server_controller'
require 'sqlite3'
require 'json'

class ServerModel
  attr_accessor :jsf

  # Method: get_structure
  # Safely get the structure
  def self.get_structure()
    return JSON.parse(IO.read("./json/#{@jsf}.json"))["id"]
  end

  # Method: get_all_entries
  # Get all the entries from the fields specified in a JSON-parsed hash
  def self.get_all_entries(db, jsf)
    @jsf = jsf
    jso = Hash.new()
 
    # Connect to database (assuming SQLite)
    dblink = SQLite3::Database.open("./db/#{db}.db")
    dblink.results_as_hash = true
    rows = dblink.execute("SELECT * FROM #{self.get_structure.values[0].split('/')[0]};")

    # Iterate over all rows of this table
    rows.each do |row|
      # Replace the "id" in the given JSON with the actual ID and expand it with the fields
      jso[row["id"]] = self.get_structure

      self.get_structure.each do |name, dbi|
        table = dbi.split("/")[0]
        field = dbi.split("/")[1]
        query = dblink.execute("SELECT #{field} from #{table} WHERE id=#{row['id']};")
        jso[row["id"]][name] = query[0][field]
      end
    end

    return jso
  end
end
