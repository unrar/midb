Gem::Specification.new do |s|
  s.name        = 'midb'
  s.version     = '1.1.1'
  s.date        = '2015-11-20'
  s.summary     = 'Middleware for databases'
  s.description = 'Automatically create a RESTful API for your database, all you need to write is a JSON file!'
  s.authors     = ["unrar"]
  s.email       = "joszaynka@gmail.com"
  s.files       = ["lib/midb/hooks.rb", "lib/midb/security_controller.rb", "lib/midb/server_controller.rb", "lib/midb/dbengine_model.rb", "lib/midb/server_model.rb", "lib/midb/errors_view.rb", "lib/midb/server_view.rb", "lib/midb/serverengine_controller.rb", "lib/midb.rb"]
  s.executables << 'midb'
  s.homepage    = "http://www.github.com/unrar/midb"
  s.add_runtime_dependency 'mysql2', '~> 0.3', '>= 0.3.20'
  s.add_runtime_dependency 'sqlite3', '~> 1.3', '>= 1.3.10'
  s.add_runtime_dependency 'httpclient', '~> 2.6', '>= 2.6.0.1'
  s.add_runtime_dependency 'ruby-hmac', '~> 0.4', '>= 0.4.0'
  s.license     = "TPOL"
end
