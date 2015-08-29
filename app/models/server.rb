require './app/controllers/server_controller'
require './app/models/dbengine'

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
