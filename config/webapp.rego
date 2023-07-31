package webapp

import future.keywords

# Read secret from environment, use a default value so we don't have to detect `undefined`
jwt_secret := object.get(opa.runtime().env, "EXAMPLE_APP_JWT_SECRET", "Default JWT secret")

# This error message is displayed when the the request does not contain authentication
deny_due_to_app_auth := { # [Ref-3.2a]
  "allowed": false,
  "body": "Not authenticated to application",
  "response_headers_to_add": {"content-type": "text/plain"},
  "http_status": 403,
}

# This function checks if the calling request is authenticated.
authorized(http_request) {
  # get the authorization header or default to empty string if it is missing
  authorization := object.get(http_request.headers, "authorization", "")
  # check that it contains a bearer token as we expect
  startswith(authorization, "Bearer ") == true
  # extract the suspected JWT
  token := substring(authorization, 7, -1)
  # decode and validate the suspected JWT
  [isValid, header, payload] := io.jwt.decode_verify(token, { # [Ref-4b]
    "secret": jwt_secret,
    "alg": "HS256",
    "aud": "openai-proxy-reference"
  })
  # check the JWT is valid and is intended for us
  isValid == true
  # check that the JWT claim allows us to proceed
  payload.allow_openai_chat_completions == true
}