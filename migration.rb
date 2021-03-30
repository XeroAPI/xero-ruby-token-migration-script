require 'securerandom'
require 'base64'
require 'openssl'
require 'digest/sha1'
require 'uri'
require 'json'
require 'net/http'
require 'csv'

CONSUMER_KEY = ''
SCOPES = ''
OAUTH2_CLIENT_ID = ''
OAUTH2_CLIENT_SECRET = ''

if (CONSUMER_KEY.empty? || SCOPES.empty? || OAUTH2_CLIENT_ID.empty? || OAUTH2_CLIENT_SECRET.empty?)
  raise "\n\n*** One of your constants are not set correctly ***\n\n"
end

SIGNATURE_METHOD = 'RSA-SHA1'
ENDPOINT = 'https://api.xero.com/oauth/migrate'
TIMESTAMP = Time.now.getutc.to_i.to_s

class XeroOauthMigration

  def self.encode_uri_component(data)
    URI.encode_www_form_component(data)
  end
  
  def self.get_oauth_params
    oauth_params = {}
    oauth_params['oauth_consumer_key'] = CONSUMER_KEY
    oauth_params['oauth_nonce'] = SecureRandom.uuid
    oauth_params['oauth_signature_method'] = SIGNATURE_METHOD
    oauth_params['oauth_timestamp'] = TIMESTAMP
    oauth_params['oauth_token'] = @token
    oauth_params['oauth_version'] = '1.0'
    oauth_params['tenantType'] = 'ORGANISATION'
  
    oauth_params
  end
  
  def self.to_oauth_param_string(params)
    # lexigraphically sorted params Xero is expecting
    "oauth_consumer_key=#{params['oauth_consumer_key']}" +
    "&oauth_nonce=#{params['oauth_nonce']}" +
    "&oauth_signature_method=#{params['oauth_signature_method']}" +
    "&oauth_timestamp=#{params['oauth_timestamp']}" +
    "&oauth_token=#{params['oauth_token']}" +
    "&oauth_version=#{params['oauth_version']}" +
    "&tenantType=#{params['tenantType']}"
  end
  
  def self.get_signature_base_string(http_method, param_string)
    "#{http_method.upcase}&" + # Uppercase HTTP method
    "#{encode_uri_component(ENDPOINT)}&" + # Base URI
    encode_uri_component(param_string).to_s # OAuth parameter string
  end
  
  def self.sign_signature_base_string(sbs, signing_key)
    digest = OpenSSL::Digest::SHA1.new
    rsa_key = OpenSSL::PKey::RSA.new signing_key
    signature = ''
    begin
      signature = rsa_key.sign(digest, sbs)
    rescue
      raise Exception, 'Unable to sign the signature base string.'
    end
  
    Base64.strict_encode64(signature).chomp.gsub(/\n/, '')
  end
  
  def self.get_authorization_string(oauth_params)
    header = 'OAuth '
    oauth_params.each {|entry|
      entry_key = entry[0]
      entry_val = entry[1]
      header = "#{header}#{entry_key}='#{entry_val}',"
    }
    header.slice(0, header.length - 1) # Remove trailing ,
  end

  def self.migrate_token(token)
    @token = token
    # 1) Setup your base signature
    oauth_params = get_oauth_params
    param_string = to_oauth_param_string(oauth_params)
    base_signature_string = get_signature_base_string('POST', param_string)

    # 2) Sign that with your private key
    signing_key = File.read('./privatekey.pem')
    signature = sign_signature_base_string(base_signature_string, signing_key)
    oauth_params['oauth_signature'] = encode_uri_component(signature)

    # 3) Build your authorization headers & POST params
    authorization_header = get_authorization_string(oauth_params)
    params = {
      "scope": "#{SCOPES}",
      "client_id": "#{OAUTH2_CLIENT_ID}",
      "client_secret": "#{OAUTH2_CLIENT_SECRET}"
    }

    # 4) Make your API call
    uri = URI.parse(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {'Content-Type' =>'application/json', 'Authorization': authorization_header}
    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = params.to_json
    response = http.request(request)

    return JSON.parse(response.body)
  end
end

tokens_to_migrate = JSON.parse(File.read('./oauth1_tokens.json'))
new_tokens = []
tokens_to_migrate.each do |oauth1_token|
  new_tokens << XeroOauthMigration.migrate_token(oauth1_token['token'])
end

File.open("oauth2_tokens.json","w") do |f|
  new_token_json = JSON.pretty_generate(new_tokens)
  puts new_token_json
  f.puts new_token_json
end
