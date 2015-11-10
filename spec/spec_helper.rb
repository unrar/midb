require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
require_relative '../lib/midb'


RSpec.configure do |config|
  # Use color in STDOUT and files
  config.color = true
  config.tty = true
  #config.expect_with(:rspec) { |c| c.syntax = :should }

  # Format
  config.formatter = :documentation
end