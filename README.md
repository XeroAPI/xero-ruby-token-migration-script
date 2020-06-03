# Xero Ruby Token Migration Script

This project shows a low level breakdown of how to make an authorized XeroAPI call to [migrate your XeroAPI connection to OAuth2.0](https://developer.xero.com/documentation/oauth2/migrate).

Requires `ruby 2.7.0`

To use this to migrate your XeroAPI tokens you need to configure the following:
* Rename `privatekey.pem.sample` to `privatekey.pem` and replace the contents with your actual private key
* Replace the contents of `oauth1_tokens.json` with an array of valid OAuth1.0a tokens ( Tokens must be refreshed prior to exchanging them for Oauth2.0 tokens )
* Replace the following constant values with your own:
  * CONSUMER_KEY = 'YOUR_CONSUMER_KEY'
  * SCOPES = 'offline_access SCOPE_1 SCOPE_2 SCOPE_3'
  * OAUTH2_CLIENT_ID = 'YOUR_OAUTH2_CLIENT_ID'
  * OAUTH2_CLIENT_SECRET = 'YOUR_OAUTH2_CLIENT_SECRET'

Running the script `ruby migration.rb` will output your new OAuth2.0 token_sets in a file called `oauth2_tokens.json` and it will also print out JSON of your converted tokens.

After that you will need to get those `token_sets` into your software system and configure your new API calls to use the new `access_token`, `xero_tenant_id`, and `refresh_token` to persist offline access indefinitely.
