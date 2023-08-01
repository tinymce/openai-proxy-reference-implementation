package envoy.authz

import future.keywords
import input.attributes.request.http as http_request # access the request data
import data.openai # import functions from openai.rego
import data.webapp # import functions from webapp.rego

default action_allowed = false

# Allow CORS preflight checks
allow := { "allowed": true } if {
  http_request.method == "OPTIONS"
}

# Non-OPTIONS requests need to be validated
allow := webapp.deny_due_to_app_auth if { # check for valid authentication [Ref-4a]
  not webapp.authorized(http_request) # see webapp.rego for details
} else := openai.deny_due_to_missing_api_key if { # check server configuration to avoid confusing error message
  not openai.api_key_ok # see openai.rego for details
} else := openai.deny_due_to_moderation(moderation.violations) if {	# check OpenAI moderation [Ref-5]
  http_request.method == "POST" # only moderate post requests
  http_request.path == "/v1/chat/completions" # only moderate requests to the completions API
  moderation := openai.moderate(input.parsed_body.messages[_].content) # see openai.rego for details
  not moderation.ok
} else := openai.allow_to_openai # finally allow the request to be forwarded [Ref-7]
