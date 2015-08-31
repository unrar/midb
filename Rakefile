task :build_gem do
  sh "gem build midb.gemspec"
end

task :install_gem do
  sh "gem install midb-1.0.0.gem"
end

task :clean do
  sh "rm midb-1.0.0.gem"
  sh "gem uninstall midb"
end

task :default => [:clean, :build_gem, :install_gem] do
  puts "All good."
end
