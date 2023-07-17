package openai

import future.keywords

# Read secret from environment, use a default value so we don't have to detect `undefined`
openai_api_key := object.get(opa.runtime().env, "OPENAI_API_KEY", null)

api_key_ok := is_null(openai_api_key) == false

openai_auth_header := concat(" ", ["Bearer", openai_api_key]) if {
	api_key_ok
} else := "Bearer unknown"

allow_to_openai := {
	"allowed": true,
	"headers": {"authorization": openai_auth_header},
}

deny_due_to_moderation(violations) := {
	"allowed": false,
	"body": concat(" ", [
		"Moderation policies violated:",
		concat(", ", violations),
	]),
	"response_headers_to_add": {"content-type": "text/plain"},
	"http_status": 400,
}

# https://platform.openai.com/docs/api-reference/moderations
moderate(inputs) := outcome if {
	print("Moderating inputs", inputs)
	moderation_response := http.send({ # [Ref-3]
		"method": "POST",
		"url": "https://api.openai.com/v1/moderations",
		"headers": {"authorization": openai_auth_header},
		"body": {
			"input": inputs,
			"model": "text-moderation-latest",
		},
	})

	# {
	# 	"id": "modr-5MWoLO",
	# 	"model": "text-moderation-001",
	# 	"results": [
	# 		{
	# 			"categories": {
	# 				"hate": false,
	# 				"hate/threatening": true,
	# 				"self-harm": false,
	# 				"sexual": false,
	# 				"sexual/minors": false,
	# 				"violence": true,
	# 				"violence/graphic": false
	# 			},
	# 			"category_scores": {
	# 				"hate": 0.22714105248451233,
	# 				"hate/threatening": 0.4132447838783264,
	# 				"self-harm": 0.005232391878962517,
	# 				"sexual": 0.01407341007143259,
	# 				"sexual/minors": 0.0038522258400917053,
	# 				"violence": 0.9223177433013916,
	# 				"violence/graphic": 0.036865197122097015
	# 			},
	# 			"flagged": true
	# 		}
	# 	]
	# }
	# [Ref-3.1] [Ref-3.2]
	print("Received moderation response", moderation_response)
	ok := all({ok |
		some i
		result := moderation_response.body.results[i]
		ok := result.flagged == false
	})
	violations := union({violations |
		some i
		result := moderation_response.body.results[i]
		categories := result.categories
		violations := {k |
			some k
			categories[k]
		}
	})
	print("ok", ok)
	print("violations", violations)
	outcome := {
		"ok": ok,
		"violations": violations,
	}
}

authorize_openai_chat(req, moderation) := deny_due_to_moderation(moderation.violations) if {
	not moderation.ok
} else := allow_to_openai # [Ref-4]
