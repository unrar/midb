# Example client for midb.
# Uses httpclient to test the test API

require 'httpclient'
require 'hmac-sha1'
require 'base64'
require 'cgi'
require 'uri'
require 'json'

def create_header(body)
  key = "example"
  #signature = URI.encode_www_form(body)
  signature = body
  hmac = HMAC::SHA1.new(key)
  hmac.update(signature)
  {"Authentication" =>"hmac " + CGI.escape(Base64.encode64("#{hmac.digest}"))}
end

c = HTTPClient.new

# See what we got in the database
body = "users" # That's what we want to sign with HMAC
header = create_header(body)
# The body=body part is useless but it won't work otherwise
res = c.get("http://localhost:8081/users", body=body, header=header)
puts res.body



