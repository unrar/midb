require 'midb'

module MIDB
  module API
    class Hooks
      def self.after_get_all_entries()
        puts "addin"
      end
    end
  end
end