package webapp

import future.keywords

# This error message is displayed when the /authenticated endpoint does
# not return 200 OK.
deny_due_to_app_auth := { # [Ref-1.2]
  "allowed": false,
  "body": "Not authenticated to application",
  "response_headers_to_add": {"content-type": "text/plain"},
  "http_status": 403,
}

# This function checks if the calling request is authenticated.
authenticated(http_request) := outcome if {
  # call the /authenticated endpoint on the example app which checks the cookie,
  # other approaches might be to use a signed JWT which could be validated by OPA
  # see https://www.openpolicyagent.org/docs/latest/external-data/#option-1-jwt-tokens
  authenticated_response := http.send({
    "method": "GET",
    "url": "http://example-app:3000/authenticated",
    "headers": { "cookie": http_request.headers.cookie }, # the example app uses cookies for session management
    "raise_error": false # getting status code 403 would normally end the processing
  })
  # we expect 200 OK for authenticated users
  outcome := authenticated_response.status_code == 200
}