package envoy.authz

import future.keywords
import input.attributes.request.http as http_request
import data.openai

default action_allowed = false

deny_due_to_app_auth := {
	"allowed": false,
	"body": "Not authenticated to application",
	"response_headers_to_add": {"content-type": "text/plain"},
	"http_status": 400,
}

# Allow CORS preflight checks
allow := { "allowed": true } if {
	http_request.method == "OPTIONS"
}


allow := deny_due_to_app_auth if { # check authentication
	authenticated_response := http.send({
		"method": "GET",
		"url": "http://example-app:3000/authenticated",
		"headers": { "cookie": http_request.headers.cookie },
		"raise_error": false
	})
	not authenticated_response.status_code == 200
} else := openai.authorize_openai_chat(input.parsed_body, moderation) if {	# check OpenAI moderation
	http_request.method == "POST"
	http_request.path == "/v1/chat/completions"
	moderation := openai.moderate(input.parsed_body.messages[_].content)
}
