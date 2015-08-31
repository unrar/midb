require 'midb/server_controller'

# This controller handles errors.
module MIDB
  class ErrorsView
    # Method: die
    # Handles arguments that cause program termination.
    # Errors: :noargs, :server_already_started
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
  end
end