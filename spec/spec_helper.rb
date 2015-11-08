require "codeclimate-test-reporter"
require_relative '../lib/midb'

CodeClimate::TestReporter.start

RSpec.configure do |config|
  # Use color in STDOUT and files
  config.color = true
  config.tty = true
  config.expect_with(:rspec) { |c| c.syntax = :should }

  # Format
  config.formatter = :documentation
end