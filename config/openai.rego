package openai

import future.keywords

# Read secret from environment, use a default value so we don't have to detect `undefined`
openai_api_key := object.get(opa.runtime().env, "OPENAI_API_KEY", null)

# Check the existance of the API key (don't try to validate it)
api_key_ok := is_null(openai_api_key) == false

# Create the content of the authorization header used in requests to OpenAI
openai_auth_header := concat(" ", ["Bearer", openai_api_key]) if {
  api_key_ok
} else := "Bearer unknown" # fallback in case API key is not provided

# This response will allow the request to be forwarded to OpenAI for processing. [Ref-6]
allow_to_openai := {
  "allowed": true,
  "headers": {"authorization": openai_auth_header},
}

# This error message exists to give the installer a hint of what may be wrong
# when the server is configured incorrectly rather than attempt to send an 
# invalid request to OpenAI and get a more confusing error.
deny_due_to_missing_api_key := {
  "allowed": false,
  "body": "Required environment variable OPENAI_API_KEY is not set",
  "response_headers_to_add": {"content-type": "text/plain"},
  "http_status": 500,
}

# This function generates a response to be used if OpenAI moderation fails.
deny_due_to_moderation(violations) := {
  "allowed": false,
  "body": concat(" ", [
    "Moderation policies violated:",
    concat(", ", violations),
  ]),
  "response_headers_to_add": {"content-type": "text/plain"},
  "http_status": 400,
}

# This function performs moderation on the inputs to see if they would be 
# accepted by OpenAI.
# Moderation is useful because it avoids a more expensive API call.
# https://platform.openai.com/docs/api-reference/moderations
moderate(inputs) := outcome if {

  # log the input to help debugging
  print("Moderating inputs", inputs)

  # Request a moderation from OpenAI to see if the input contains content
  # that violates their policies and would be rejected.
  moderation_response := http.send({ # [Ref-5]
    "method": "POST",
    "url": "https://api.openai.com/v1/moderations",
    "headers": {"authorization": openai_auth_header},
    "body": {
      "input": inputs,
      "model": "text-moderation-latest",
    },
  })

  # This is an example of what a failed moderations response might look like:
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
  
  # log the moderation response to help debugging
  print("Received moderation response", moderation_response)

  # extract out the results array
  moderation_results := moderation_response.body.results # [Ref-5.1] [Ref-5.2]

  # check that the `flagged` property is false for all of the result array entries.
  ok := all({ok |
    some i
    result := moderation_results[i]
    ok := result.flagged == false
  })

  # collect all the category names that are set to true in all the result array entries.
  violations := union({violations |
    some i
    result := moderation_results[i]
    categories := result.categories
    violations := {k |
      some k
      categories[k]
    }
  })

  # some logging to help debugging
  print("ok", ok)
  print("violations", violations)

  # update outcome so it can be returned
  outcome := {
    "ok": ok,
    "violations": violations,
  }

}
