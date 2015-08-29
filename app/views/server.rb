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
          end
    puts msg
  end
end
