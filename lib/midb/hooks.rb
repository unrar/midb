# ADDED in midb-2.0.0a  by unrar #
#
# The "hooks" part of the MIDB::API module allows programmers to customize their API.
# Hooks are methods that are run in the API; overriding them allows you to run a custom API.
#
# This hooking technology has been developed in its-hookable.
#
module MIDB
  module API
    class Hooks
      attr_accessor :hooks
      def initialize()
        @hooks = Hash.new
        @hooks["after_get_all_entries"] = []
        @hooks["format_field"] = []
      end

      # This method adds a method _reference_ (:whatever) to the hash defined above.
      def register(hook, method)
        @hooks[hook].push method
      end

      # These are the methods that are ran when the hook is called from the main class.
      # The code can be slightly modified depending on the arguments that each hook takes,
      # but that's up to the original developer - not the one who does the customization.


      def after_get_all_entries(n_entries)
        @hooks["after_get_all_entries"].each do |f|
          # Just run :f whenever this method is called, no arguments.
          Object.send(f, n_entries)
        end
      end

      def format_field(field, what)
        if @hooks["format_field"] == []
          return what
        else
          @hooks["format_field"].each do |f|
            return Object.send(f, field, what)
          end
        end
      end
    end
  end
end
