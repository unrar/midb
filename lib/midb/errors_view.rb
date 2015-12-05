module MIDB
  module Interface
    # A view that outputs errors.
    class Errors
      # Handles fatal errors that will cause the application to abrort.
      # 
      # @param err [Symbol] The ID of the error that's to be reported.
      def self.die(err)
        errmsg =  case err
          when :noargs then "No command supplied. See `midb help`."
          when :server_already_started then "The server has already been started and is running."
          when :server_not_running then "The server isn't running."
          when :server_error then "Error while starting server."
          when :no_serves then "No files are being served. Try running `midb serve file.json`"
          when :syntax then "Syntax error. See `midb help`"
          when :file_404 then "File not found."
          when :not_json then "Specified file isn't JSON!"
          when :json_exists then "Specified file is already being served."
          when :json_not_exists then "The JSON file isn't being served."
          when :unsupported_engine then "The specified database engine isn't supported by midb."
          when :already_project then "This directory already contains a midb project."
          when :bootstrap then "midb hasn't been bootstraped in this folder. Run `midb bootstrap`."
          when :no_help then "No help available for this command. See a list of commands with `midb help`."
          else "Unknown error: #{err.to_s}"
        end
        abort("Fatal error: #{errmsg}")
      end
      def self.exception(exc)
        excmsg = case exc
          when :database_error then "An error occurred when trying to connect to the database."
          when :query_error then "An error occurred when trying to query the database."
          else "Unknown exception: #{exc.to_s}"
        end
        puts "(exception)\t#{excmsg}"
      end
    end
  end
end