require 'hmac-sha1'
require 'base64'
require 'cgi'

module MIDB
  module API
    # Controller that handles API HMAC authentication.
    # 
    # @note This will probably become a separate project soon.
    class Security

      # Checks if an HTTP header is the authorization one
      #
      # @deprecated It's no longer used but kept for historical reasons.
      # @param header [String] A line of an HTTP header.
      # @return [Boolean] Whether it's an auth header or not.
      def self.is_auth?(header)
         return header.split(":")[0].downcase == "authentication"
      end

      # Parses an authentication header so to get the HMAC digest.
      #
      # @param header [String] A line of an HTTP header (should have been checked
      #                         to be an auth header)
      # @return [String] The HMAC digest as a string.
      def self.parse_auth(header)
        return header.split(" ")[1]
      end

      # Checks if an HMAC digest is properly authenticated.
      # 
      # @param header [String] A line of an HTTP header (see #parse_auth)
      # @param params [String] The data passed via the HTTP request.
      # @param key [String] The private API key.
      #
      # @return [Boolean] Whether the given digest matches the correct one or not.
      def self.check?(header, params, key)
        hmac = HMAC::SHA1.new(key)
        hmac.update(params)
        return self.parse_auth(header) == CGI.escape(Base64.encode64("#{hmac.digest}"))
      end
    end
  end
end
