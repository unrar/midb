require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
task :build_gem do
  sh "gem build midb.gemspec"
end

task :install_gem do
  sh "gem install midb-1.1.0.gem"
end

task :test do
  sh "rspec spec"
end

task :clean do
  sh "rm midb-*.gem"
  sh "gem uninstall midb"
end

task :default => [:clean, :build_gem, :install_gem, :test] do
  puts "All good."
end
