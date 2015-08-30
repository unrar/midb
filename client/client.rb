# Example client for midb
require 'httpclient'
require 'hmac-sha1'
require 'base64'
require 'cgi'

key = "example"
signature = "name=test&age=16"
hmac = HMAC::SHA1.new(key)
hmac.update(signature)

c = HTTPClient.new
header = {"Authentication" =>"hmac " + CGI.escape(Base64.encode64("#{hmac.digest}"))}
body = {"name" => "test", "age" => 16}
res = c.post("http://localhost:8081/test", body=body, header=header)
puts res.body