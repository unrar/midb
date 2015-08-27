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
end
