# ADDED in midb-2.0.0a  by unrar #
#
# The "hooks" part of the MIDB::API module allows programmers to customize their API.
# Hooks are methods that are run in the API; overriding them allows you to run a custom API.
#
module MIDB
  module API
    class Hooks
      def self.after_get_all_entries()
      end
    end
  end
end
