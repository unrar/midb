require 'midb/server_controller'
require 'sqlite3'
require 'mysql2'

module MIDB
  class DbengineModel
    attr_accessor :engine, :host, :uname, :pwd, :port, :db
    def initialize()
      @engine = MIDB::ServerController.config["dbengine"]
      @host = MIDB::ServerController.config["dbhost"]
      @port = MIDB::ServerController.config["dbport"]
      @uname = MIDB::ServerController.config["dbuser"]
      @pwd = MIDB::ServerController.config["dbpassword"]
      @db = MIDB::ServerController.db
    end
    # Method: connect
    # Connect to the specified database
    def connect()
      if @engine == :sqlite3
        sq = SQLite3::Database.open("./db/#{@db}.db")
        sq.results_as_hash = true
        return sq
      elsif @engine == :mysql
        return Mysql2::Client.new(:host => @host, :username => @uname, :password => @pwd, :database => @db)
      end
    end

    # Method: query
    # Perform a query, return a hash
    def query(res, query)
      if @engine == :sqlite3
        return res.execute(query)
      elsif @engine == :mysql
        return res.query(query)
      end
    end

    # Method: extract
    # Extract a field from a query
    def extract(result, field)
      if @engine == :sqlite3
        return result[0][field] || result[field]
      elsif @engine == :mysql
        result.each do |row|
          return row[field]
        end
      end
    end
  end
end