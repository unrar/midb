require 'hmac-sha1'
require 'base64'
require 'cgi'
require './app/controllers/server_controller'

# midb security controller - handles API authentication 
# this will probably become another different project soon!

class SecurityController

  # Method: is_auth?
  # Checks if an HTTP header is the authorization one
  def self.is_auth?(header)
     return header.split(":")[0].downcase == "authentication"
  end

  # Method: parse_auth
  # Parses an authentication header
  def self.parse_auth(header)
    return header.split(" ")[1]
  end

  # Method: check?
  # Checks if an HMAC digest is properly authenticated
  def self.check?(header, params, key)
    signature = params
    hmac = HMAC::SHA1.new(key)
    hmac.update(signature)
    return self.parse_auth(header) == CGI.escape(Base64.encode64("#{hmac.digest}"))
  end

end
