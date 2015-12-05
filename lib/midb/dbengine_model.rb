require 'sqlite3'
require 'mysql2'
require 'midb/errors_view'
module MIDB
  module API
    # @author unrar
    # This class handles engine-dependent database operations
    class Dbengine

      # @!attribute engine
      #   @return [Symbol] The database engine being used
      # @!attribute host
      #   @return [String] Host name where the database is located
      # @!attribute uname
      #   @return [String] Username for the database
      # @!attribute pwd
      #   @return [String] Password for the database.
      # @!attribute port
      #   @return [Fixnum] Port for the database
      # @!attribute db
      #   @return [String] Name of the database  
      attr_accessor :engine, :host, :uname, :pwd, :port, :db

      # Constructor - initializes the attributes with the configuration from ServerController
      #
      # @param cnf [Array<String>] The configuration array.
      # @param db  [String] Database name.
      def initialize(cnf, db)
        @engine = cnf["dbengine"]
        @host = cnf["dbhost"]
        @port = cnf["dbport"]
        @uname = cnf["dbuser"]
        @pwd = cnf["dbpassword"]
        @db = db
      end

      # Connect to the specified database
      #
      # @return [SQLite3::Database, Mysql2::Client] A resource referencing to the database
      def connect()
        begin
          # Connect to an SQLite3 database
          if @engine == :sqlite3
            sq = SQLite3::Database.open("./db/#{@db}.db")
            sq.results_as_hash = true
            return sq
          # Connect to a MySQL database
          elsif @engine == :mysql
            return Mysql2::Client.new(:host => @host, :username => @uname, :password => @pwd, :database => @db)
          end
        rescue
          MIDB::Interface::Errors.exception(:database_error)
          return false
        end
      end

      # Perform a query to the database.
      #
      # @param res [SQLite3::Database, Mysql2::Client] An existing database resource.
      # @param query [String] The SQL query to be ran.
      #
      # @return [Array, Hash] Returns an array of hashes for SQLite3 or a hash for MySQL
      def query(res, query)
        begin
          if @engine == :sqlite3
            return res.execute(query)
          elsif @engine == :mysql
            return res.query(query)
          end
        rescue
          MIDB::Interface::Errors.exception(:query_error)
          return false
        end
      end

      # Extract a field from a query, because different engines return different types (see #query)
      #
      # @param result [Array, Hash] The result of a query obtained via #query
      # @param field [String] The name of the field to be extracted.
      #
      # @return [String, Fixnum] The field extracted from a query
      def extract(result, field)
        if @engine == :sqlite3
          return result[0][field] || result[field]
        elsif @engine == :mysql
          result.each do |row|
            return row[field]
          end
        end
      end

      # Returns the length of a result, because different engines return diferent types (see #query)
      #
      # @param result [Array, Hash] The result of a query obtained via #query
      # 
      # @return [Fixnum] Length of the result.
      def length(result)
        if @engine == :sqlite3
          return result.length
        elsif @engine == :mysql 
          return result.count
        end
      end
    end
  end
end