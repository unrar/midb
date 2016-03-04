#!/usr/bin/env ruby
# This script is part of midb, and generates a HMAC digest 
require 'hmac-sha1'
require 'base64'
require 'cgi'

if ARGV.length < 2 then
  puts "[syntax error] ./hmac.rb <string_to_encode> <key>"
else
  hmac = HMAC::SHA1.new(ARGV[1])
  hmac.update(ARGV[0])
  puts "[hmac digest] #{CGI.escape(Base64.encode64("#{hmac.digest}"))}"
end