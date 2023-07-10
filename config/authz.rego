package envoy.authz

import future.keywords
import input.attributes.request.http as http_request
import data.openai

default action_allowed = false

# Allow CORS preflight checks
allow := { "allowed": true } if {
	http_request.method == "OPTIONS"
}

# OpenAI
allow := openai.authorize_openai_chat(input.parsed_body, moderation, example_app_approves) if {
	http_request.method == "POST"
	http_request.path == "/v1/chat/completions"
	moderation := openai.moderate(input.parsed_body.messages[_].content)
	authenticated_response := http.send({
		"method": "GET",
		"url": "http://example-app:3000/authenticated",
		"headers": { "cookie": http_request.headers.cookie },
		"raise_error": false
	})
	example_app_approves := authenticated_response.status_code == 200
}
