require './app/controllers/server_controller'

# This controller handles errors.
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
              else "Unknown error"
              end
    abort("Fatal error: #{errmsg}")

  end
end
