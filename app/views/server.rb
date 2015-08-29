require './app/controllers/server_controller'
class ServerView
  def self.success()
    puts "Ayyy great"
  end

  # Method: show_serving
  # Shows the files being served
  def self.show_serving()
    puts "The follow JSON files are being served as APIs:"
    ServerController.config["serves"].each do |serv|
      puts "- #{serv}"
    end
  end

  # Method: server_stopped
  # Notice that the server has been stopped.
  def self.server_stopped()
    puts "The server has been successfully stopped!"
  end

  # Method: info
  # Send some info
  def self.info(what, info=nil)
    msg = case what
          when :start then "Server started on port #{info}. Listening for connections..."
          when :incoming_request then "> Incoming request from #{info}."
          when :request then ">> Request method: #{info[0]}\n>>> Endpoint: #{info[1]}"
          when :match_json then ">> The request matched a JSON file: #{info}.json\n>> Creating response..."
          when :response then ">> Sending JSON response (RAW):\n#{info}"
          when :success then "> Successfully managed this request!"
          when :not_found then "> Invalid endpoint - sending a 404 error."
          end
    puts msg
  end

  # Method: out_config
  # Output some config
  def self.out_config(what)
    msg = case what
          when :dbengine then "Database engine: #{ServerController.config['dbengine']}."
          when :dbhost then "Database server host: #{ServerController.config['dbhost']}."
          when :dbport then "Database server port: #{ServerController.config['dbport']}."
          when :dbuser then "Database server user: #{ServerController.config['dbuser']}."
          when :dbpassword then "Database server password: #{ServerController.config['dbpassword']}."
          else "Error??"
          end
    puts msg
  end
end
