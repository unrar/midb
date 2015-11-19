require 'midb'

module MIDB
  module API
    class Hooks
      def self.after_get_all_entries()
        puts "AYY IM HOOKED"
      end
    end
   end
end

require_relative ("./addin")
cc = Hash.new
cc["dbengine"] = :sqlite3
engy = MIDB::API::Engine.new("test", "100 WAITING", cc)
dbop = MIDB::API::Model.new("users", "test", engy)
dbop.get_all_entries()
