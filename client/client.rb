# Example client for midb
require 'httpclient'
require 'hmac-sha1'
require 'base64'
require 'cgi'
require 'uri'

def create_header(body)
  key = "example"
  signature = URI.encode_www_form(body)
  hmac = HMAC::SHA1.new(key)
  hmac.update(signature)
  {"Authentication" =>"hmac " + CGI.escape(Base64.encode64("#{hmac.digest}"))}
end

c = HTTPClient.new
body = {"name" => "somebody", "age" => 20, "password" => "openaccess"}
header = create_header(body)
res = c.post("http://localhost:8081/test", body=body, header=header)
puts res.body

