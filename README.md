# Xero Ruby Token Migration Script

This project is for XeroAPI developers who are migrating their [Partner Application](https://developer.xero.com/documentation/auth-and-limits/partner-applications) to the new standard OAuth2.0 [authorization flow](https://developer.xero.com/documentation/oauth2/migrate). It is a low dependency script that sets up the required OAuth1.0a headers, POST's to Xero's migration endpoint, and returns a JSON array of newly minted OAuth2.0 tokens.

To use this script to migrate your OAuth1.0a XeroAPI tokens you need to:
> Replace 2 files
* Rename `privatekey.pem.sample` to `privatekey.pem` and replace with your own private key
* Replace `oauth1_tokens.json` with an array of valid OAuth1.0a tokens
> Replace 4 variables in `migration.rb`
  * CONSUMER_KEY
  * SCOPES
  * OAUTH2_CLIENT_ID
  * OAUTH2_CLIENT_SECRET

Read more about [Xero scopes](https://developer.xero.com/documentation/oauth2/scopes) to ensure you are only requiring the neccesary user permissions to your new access_token.

## Running the script
Requires `ruby 2.7.0`
```bash
ruby migration.rb
```
## Example output

Running the script should output your new OAuth2.0 token_sets in a file `oauth2_tokens.json` and print out JSON of your converted tokens to STDOUT. 

With 1 recently refreshed OAuth1.0a token:
```json
[
  { "token": "xxxxxxxxxxxxxxxxxxxxx" }
]
```

Should write to `oauth2_tokens.json` and return an array of OAuth2.0 `token_sets` when parsed look like:
```json
[
  { 
    "access_token": "xxxxxxxxxx.xxxxxxxxxx",
    "refresh_token": "xxxxxxxxxx",
    "expires_in": "1800",
    "token_type": "Bearer",
    "xero_tenant_id": "xxxx-xxxx-xxxx-xxxx-xxxxxxxxx"
  }
]
```

If you have multiple valid OAuth1.0a tokens you want to migrate simply add to the input file.
```
{ "token": "xxxxxxxxxxxxxxxxxxxxx" },
{ "token": "xxxxxxxxxxxxxxxxxxxxx" }
```

## Re-Integrate your tokens
Get the new `token_sets` into your system and make sure to configure your new API calls to use the new `access_token` & `xero_tenant_id` header. We have a set of [supported SDK's](https://developer.xero.com/documentation/libraries/overview) to help make OAuth2.0 API calls and new user authentication easier.

🥳

# Code Walkthrough

If you want to see a step through explanation of everything in the `migrate.rb` file i've outlined every step so you could know how to build up OAuth1.0a headers in any other language.

### 1) Configure Variables

You will need to track down the following variables from your OA1, and OA2 applications.

```ruby
require 'securerandom'

TOKEN = 'VALID_OAUTH_10A_ACCESS_TOKEN'
CONSUMER_KEY = 'YOUR_CONSUMER_KEY'
SCOPES = 'offline_access accounting.transactions accounting.settings'
OAUTH2_CLIENT_ID = 'YOUR_OAUTH20_CLIENT_ID'
OAUTH2_CLIENT_SECRET = 'YOUR_OAUTH20_CLIENT_SECRET'

SIGNATURE_METHOD = 'RSA-SHA1'
ENDPOINT = 'https://api.xero.com/oauth/migrate'
NONCE = SecureRandom.uuid
TIMESTAMP = Time.now.getutc.to_i.to_s
```

### 2) Set up Base Signature
Interpolate params into the base string that will be encrypted, encoded and passed to the API to validate our API call. I've already lexicographically ordered / alphabetized all our required parameters.

```ruby
base_params = "oauth_consumer_key=#{CONSUMER_KEY}" +
"&oauth_nonce=#{NONCE}" +
"&oauth_signature_method=#{SIGNATURE_METHOD}" +
"&oauth_timestamp=#{TIMESTAMP}" +
"&oauth_token=#{TOKEN}" +
"&oauth_version=1.0" +
"&tenantType=ORGANISATION"
```

```bash
base_params 
=> "oauth_consumer_key=YOUR_CONSUMER_KEY&oauth_nonce=1cbf3d69-d478-4956-b574-a4c6c4a4b2c4&oauth_signature_method=RSA-SHA1&oauth_timestamp=1591214409&oauth_token=VALID_OAUTH_10A_ACCESS_TOKEN&oauth_version=1.0&tenantType=ORGANISATION"
```

### 3) Format and Encode Base Signature
We can now finalize the format of our base_signature_string which is built up with 3 main components:
1. Uppercase HTTP Method
2. URL encoded Base URI
3. URL encoded base_params

```ruby
require 'uri'

signature_base_string = "POST&" + # Uppercase HTTP method
"#{URI.encode_www_form_component(ENDPOINT)}&" + # Base URI
URI.encode_www_form_component(base_params).to_s # OAuth parameter string
```

Returns the following structured partially url encoded stringsignature_base_string
```bash
signature_base_string
=> "POST&https%3A%2F%2Fapi.xero.com%2Foauth%2Fmigrate&oauth_consumer_key%3DVCQSO0TYNV3I33Z4LOHD4UXGVKZNPQ%26oauth_nonce%3D1cbf3d69-d478-4956-b574-a4c6c4a4b2c%26oauth_signature_method%3DRSA-SHA1%26oauth_timestamp%1591214409%26oauth_token%TOKEN%26oauth_version%3D1.0%26tenantType%3DORGANISATION"
```

### 4) Sign `signature_base_string` With Private Key
We now have the `signature_base_string` we can sign using our private key that is associated with OA1 Partner app's public cert that we previously uploaded to our Partner app https://developer.xero.com/myapps/details?appId=<uuid> dashboard.

*If you are unable to track this down you can always regenerate a new set, re-upload public cert to the Xero app dash & put the private key on your server / in this script.*

We then sign our base_signature_string with the `SHA-1` digest and our `privatekey.pem`.

The resulting signature being `Base64` then `URL` encoded.

```ruby
require 'uri'
require 'base64'
require 'openssl'
require 'digest/sha1'

signing_key = File.read('./privatekey.pem')
rsa_key = OpenSSL::PKey::RSA.new signing_key
digest = OpenSSL::Digest::SHA1.new
signature = rsa_key.sign(digest, signature_base_string)

Base64.strict_encode64(signature).chomp.gsub(/\n/, '')

oauth_signature = URI.encode_www_form_component(signature)
```

```bash
oauth_signature
=> "dkkQVrBsTfWqCatt4xxxxxe3Aitmje5jtjjoWxxxZl%2BuriiCjY%2Fe%2FgM6B0ogG%f4LKCJVPaS9Y6atX8734xxxz0hLhVREIDtNFEb%2BpxxxejeI%3D"
```

### Step 4) Build your authorization headers & POST params
Now we can format our final API call header & body parameters

```ruby
authorization_headers = "OAuth oauth_consumer_key='#{CONSUMER_KEY}',
oauth_nonce='#{NONCE}',
oauth_signature_method='#{SIGNATURE_METHOD}',
oauth_timestamp='#{TIMESTAMP}',
oauth_token='#{TOKEN}',
oauth_version='1.0',
tenantType='ORGANISATION',
oauth_signature='#{oauth_signature}'".gsub("\n",' ')

params = {
  "scope": "#{SCOPES}",
  "client_id": "#{OAUTH2_CLIENT_ID}",
  "client_secret": "#{OAUTH2_CLIENT_SECRET}"
}
```

```bash
authorization_headers
=> "OAuth oauth_consumer_key='YOUR_CONSUMER_KEY', oauth_nonce='1cbf3d69-d478-4956-b574-a4c6c4a4b2c4', oauth_signature_method='RSA-SHA1', oauth_timestamp='1591214409', oauth_token='VALID_OAUTH_10A_ACCESS_TOKEN', oauth_version='1.0', tenantType='ORGANISATION', oauth_signature='dkkQVrBsTfWqCatt4xxxxxe3Aitmje5jtjjoWxxxZl%2BuriiCjY%2Fe%2FgM9M9XW75DeRXX1xxxI6B0ogGylF9myRTv6KhDpEpxxxtdaJ0b2LdcWbODHhLP98%f4LKCJVPaS9Y6atX8734xxxz0hLhVREIDtNFEb%2BpxxxejeI%3D'"

params
=> { scope: "offline_access accounting.transactions accounting.settings", client_id: "YOUR_OAUTH20_CLIENT_ID", client_secret: "YOUR_OAUTH20_CLIENT_SECRET" }
```

### 5) Make your API call
Finally we are ready to exchange our OA1 token for an OA2 token_set
1. Format the `Authorization: header`
2. Add the POST body in json format
3. Make the API call

```ruby
require 'uri'
require 'json'
require 'net/http'

uri = URI.parse(ENDPOINT)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

headers = {'Content-Type' =>'application/json', 'Authorization': authorization_header}
request = Net::HTTP::Post.new(uri.request_uri, headers)
request.body = params.to_json
response = http.request(request)
```

```bash
puts response.body
```

```json
{
  "access_token":"xxxxxx.xxxxxx.xxxxxx-xxxxx-xxxxx-xxxxx",
  "refresh_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "expires_in":"1800",
  "token_type":"Bearer",
  "xero_tenant_id":"xxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
}
```

### Step 6) Move new token_set to your production environment
You'r now the proud owner of a OA2 token set for your XeroAPI connections!

If you were to head over to https://jwt.io/ and decode the new access_token you can see some interesting info regarding your new connection.

You will also see there is a new very important field returned in the OA2 token_set: `"xero_tenant_id": "xxx-xxx-xxx-xxx"`.

This is the largest difference between the two authorization gateways. We now have the ability to have multiple organisations authenticated by a user under the same "access_token". Due to this enhancement each API call will need to have the xero_tenant_id specified in the header. Fortunately we have a suite of Xero supported SDK's that make this easy. They also include tooling for your new signups to authorize and return valid token_sets back to your application.