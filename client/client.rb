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
  signature = URI.encode_www_form(body)
  hmac = HMAC::SHA1.new(key)
  hmac.update(signature)
  {"Authentication" =>"hmac " + CGI.escape(Base64.encode64("#{hmac.digest}"))}
end

c = HTTPClient.new

# See what we got in the database
puts c.get("http://localhost:8081/test").body

# Insert something
body = {"name" => "unrar", "age" => 17, "password" => "can_you_not!"}
header = create_header(body)
res = c.post("http://localhost:8081/test/", body=body, header=header)
# Parse the JSON to get the ID
jsres = JSON.parse(res.body)
id = jsres["id"]
puts res.body
puts "id: #{id}"

# Change the password
body = {"password" => "yes_i_can!"}
header = create_header(body)
res = c.put("http://localhost:8081/test/#{id}", body=body, header=header)
puts res.body


