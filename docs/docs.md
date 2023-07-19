# Ai Proxy reference docs

## Overview

This is a reference implementation showing how to integrate a TinyMCE application with the TinyMCE [AI Assistant](https://tiny.cloud/docs/tinymce/6/ai/).

It is *not* a production-ready application. It is for demonstration and training purposes only.

## First step

Review the OpenAi Proxy call flows diagram below.

It presents a high level overview of the interactions between the required components that enables the OpenAi suggestions feature.

The documentation following describes, in more detail, how to implement these interactions as a reference towards configuring your own solution.

![Diagram](flow-diagram/flowdiagram.svg)

## Component 1: the main TinyMCE application

The reference application is a NodeJS server which serves a single page *Message of the Day* application. 

The NodeJS server has 6 endpoints:

| endpoint                                            | path                         | purpose                                                                                   |
| --------------------------------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------- |
| [`GET /`](../example-app/index.js#L52)              | ../example-app/index.js#L52  | serves the application page.                                                              |
| [`GET /ai-request.js`](../example-app/index.js#L53) | ../example-app/index.js#L53  | serves the ChatGPT shim.                                                                  |
| [`GET /authenticated`](../example-app/index.js#L56) | ../example-app/index.js#L56  | returns 200 for a logged in user and 403 for a logged out (unauthenticated) user.         |
| [`GET /message`](../example-app/index.js#L59)       | ../example-app/index.js#L59  | serves the current message of the day.                                                    |
| [`POST /message`](../example-app/index.js#L71)      | ../example-app/index.js#L71  | updates the current message of the day.                                                   |
| [`POST /login`](../example-app/index.js#L87)        | ../example-app/index.js#L87  | authenticates a username/password and creates a session cookie so the users is logged-in. |
| [`POST /logout`](../example-app/index.js#L104)      | ../example-app/index.js#L104 | invalidates the session cookie so the user is logged-out


<!-- - [`GET /`](../example-app/index.js#L52) - serves the application page.
- [`GET /ai-request.js`](../example-app/index.js#L53) - serves the ChatGPT shim.
- [`GET /authenticated`](../example-app/index.js#L56) - returns 200 for a logged in user and 403 for a logged out (unauthenticated) user.
- [`GET /message`](../example-app/index.js#L59) - serves the current message of the day.
- [`POST /message`](../example-app/index.js#L71) - updates the current message of the day.
- [`POST /login`](../example-app/index.js#L87) - authenticates a username/password and creates a session cookie so the users is logged-in.
- [`POST /logout`](../example-app/index.js#L104) - invalidates the session cookie so the user is logged-out
-->

The application has 2 states: 

1. **Logged out**
  * the *Message of the day* is displayed but cannot be edited.
  * a user can login with the hardcoded credentials `admin`/`admin`  
  **Important**: this is a demonstration only, care must be taken to handle credentials properly in a production application.
  
2. **Logged in**
  * a TinyMCE editor holds the current *Message of the day* and can be used to edit it.
  * While logged-in it is possible to use the AI plugin to query Chat GPT 3.5.

### ChatGPT shim
The [`example-app/ai-request.js`](../example-app/ai-request.js) file defines a
function used as a shim between TinyMCE's AI plugin and the OpenAI API.

The AI plugin is agnostic to the AI provider, allowing you to adapt different AI backends.

To do this, the integrator has to adapt to the provider API.

This example uses ChatGPT 3.5.

- [Line 3](../example-app/ai-request.js#L3): Loads the FetchEventSource library 
which is used to work around the 2000 character limitation of the browser's 
built-in EventSource API.
- [Line 5](../example-app/ai-request.js#L5): Is the generic interface that TinyMCE
provides. The `request` parameter includes the text of the request in `request.prompt`.
The `respondWith` parameter provides adapters to different siturations. In this case
we are using `respondWith.stream` so we can get access to streaming related values.
- [Line 6](../example-app/ai-request.js#L6): The `stream` option gives us access to
`signal` which is an [AbortSignal](https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal)
and `streamMessage` which is a simple callback that takes a string to be added on
to the existing content.
- [Lines 8 to 10](../example-app/ai-request.js#L8): Get the FetchEventSource module
and immedately call it.
- [Line 11](../example-app/ai-request.js#L11): Specifies the proxy URL that we
will use to proxy all our OpenAI requests. The example code connects to ChatGPT 
via the envoy proxy running on [localhost:8080](http://localhost:8080).
- [Line 13](../example-app/ai-request.js#L13): Specifies that the stream should
be started by making a `POST` request so a `body` can be included.
- [Line 16](../example-app/ai-request.js#L16): Specifies using the `content-type` 
header that the `body` will contain JSON.  
**Note**: the `authorization` header with the OpenAI API key is not added here
as it will be added by the envoy proxy. This also serves to hide the API key
from end users.
- [Lines 17 to 23](../example-app/ai-request.js#L17): Configures ChatGPT settings
including the model used, the creativity, the maximum output length, the question posed
and that the reply should be streamed.
- [Line 24](../example-app/ai-request.js#L24): Ensures that the request will
not be canceled if the user switches away from the browser window.
- [Line 25](../example-app/ai-request.js#L25): Sets the AbortSignal so TinyMCE
can signal to the FetchEventSource call that it should be canceled when the user
closes the AI window early.
- [Lines 27 to 36](../example-app/ai-request.js#L27): Specifies how to handle
the initial connection response. By default the FetchEventStream will report a
generic error if the response type is not `text/event-stream`. As OpenAI uses
JSON to communicate error messages this method is needed to extract the error
messages so they can be provided to the end user.
- [Lines 38 to 45](../example-app/ai-request.js#L38): Converts the JSON messages
from OpenAI into the `streamMessage` calls that just take the content string.
- [Lines 47 to 49](../example-app/ai-request.js#L47): Rethrows any errors to abort
processing.

## Component 2: the proxy server

Envoy is used to proxy the requests after they are filtered by the Open Policy Agent (OPA).

This makes use of these two container images from Docker Hub:

* [envoyproxy/envoy](https://hub.docker.com/r/envoyproxy/envoy)
* [openpolicyagent/opa](https://hub.docker.com/r/openpolicyagent/opa).

These both use configuration files in the `/config/` folder.

[`envoy.yaml`](../config/envoy.yaml) configures the Envoy proxy

[`opa.yaml`](../config/opa.yaml) configures the Open Policy Agent.

The Open Policy Agent also makes use of the Rego files to script the process of authenticating and moderating the requests to be sent to OpenAI.

### envoy.yaml

The [`config/envoy.yaml`](../config/envoy.yaml) file is heavily commented but here is an overview.

- [Lines 1 to 5](../config/envoy.yaml#L1): Sets the port where the admin page is
hosted. The admin page is useful for debugging problems but it is strongly 
recommended that it not be made accessible remotely as it makes available 
serveral destructive operations.
- [Lines 8 to 16](../config/envoy.yaml#L8): Configures the proxy server to listen
to connection requests on port 8080. This is repeated for both IPv4 and IPv6 so 
that it will listen to connection attempts from both.
- [Lines 28 to 29](../config/envoy.yaml#L28): Says that the proxy is not serving 
as multiple hosts but rather treats all incomming as to a single host.
- [Lines 31 to 35](../config/envoy.yaml#L31): Tells the proxy to send everything 
that passes the filters and that goes to the path /v1/ to the OpenAI cluster 
(defined later) on behalf of the client.
- [Lines 37 to 50](../config/envoy.yaml#L37): Tells the proxy how to add CORS 
headers though it won't actually do the addition of the headers until the 
related filter.
- [Lines 52 to 62](../config/envoy.yaml#L52): Filters out requests to the health 
check "/ping" and handles it without passing the request onwards.
- [Lines 63 to 72](../config/envoy.yaml#L63): Stores the path of the request in 
a lookup for a later filter.
- [Lines 73 to 75](../config/envoy.yaml#L73): Adds the CORS headers using the 
previously defined rules (Lines 37 to 50).
- [Lines 76 to 97](../config/envoy.yaml#L76): Runs the Open Policy Agent when 
the path matches /v1/ and filters
the requests based on running the rego scripts which are specified in opa.yaml.
- [Lines 98 to 100](../config/envoy.yaml#L98): Runs the HTTP router which is 
required.
- [Lines 102 to 115](../config/envoy.yaml#L102): Tells the proxy to define the 
OpenAI cluster as all IP addresses returned by a DNS lookup on api.openai.com 
which should be contacted in a round-robin fashion. It also specifies that the 
list of IP addresses should be regularly queried to ensure changes are reflected.
- [Lines 117 to 129](../config/envoy.yaml#L117): Tells the proxy to use TLS when 
contacting api.openai.com.

### opa.yaml
The [`config/opa.yaml`](../config/opa.yaml) file defines what the open policy agent does.

- [Lines 1 to 4](../config/opa.yaml#L1): Sets the port (9191) and path (`envoy/authz/allow`) for the remote procedure call. 
The `envoy/authz/allow` refers to the package `envoy.authz` and the variable `allow` defined in the file
[`authz.rego`](../config/authz.rego).
- [Lines 5 and 6](../config/opa.yaml#L5): Enables logging to the console.

### authz.rego
The [`config/authz.rego`](../config/authz.rego) file is the entrypoint for checking
the requests. 

- [Line 4](../config/authz.rego#L4): The HTTP request data is imported so it can 
be checked before forwarding. The import is renamed to `http_request` to avoid 
being confused with the `http.send(...)` function.
- [Line 5](../config/authz.rego#L5): Functions and variables are imported from `openai.rego`.
- [Line 6](../config/authz.rego#L6): Functions and variables are imported from `webapp.rego`.
- [Lines 11 to 13](../config/authz.rego#L11): OPTIONS requests are approved so that any CORS preflight requests complete.
- [Lines 16 and 17](../config/authz.rego#L16): Authentication of the user is checked. 
See `webapp.rego` for details.
- [Lines 18 and 19](../config/authz.rego#L18): The existance of the server configuration environment variable `OPENAI_API_KEY` is checked. This is to ensure a less confusing error 
message and is not essential for a production implementation.
- [Lines 20 to 24](../config/authz.rego#L20): Any POST requests going to the
completion endpoint are moderated. See `openai.rego` for details.
- [Line 25](../config/authz.rego#L25) Finally having passed all the checks the 
request is forwarded to Open AI.

### webapp.rego
The [`config/webapp.rego`](../config/webapp.rego) file contains the logic for checking
if the client is authenticated along with the reply that is sent when authentication fails.

- [Lines 7 to 12](../config/webapp.rego#L7): Defines the error message that will be
sent if authentication of the request fails.
- [Lines 15 to 27](../config/webapp.rego#L15): Sends a request to `/authenticated`
on the example app while including all cookies. The example app validates the
cookie session and returns `200 OK` when the request is authenticated, otherwise
it returns `403 Forbidden`. The rego code checks the status code and returns
`true` when the request is authenticated.

### openai.rego
The [`config/openai.rego`](../config/openai.rego) file contains the logic for querying
the moderation endpoint of OpenAI along with the messages that should be sent

- [Line 6](../config/openai.rego#L6): Reads the environment variable 
`OPENAI_API_KEY` into a variable with the default value `null`. The default is
important because otherwise the value will be `undefined` which is very 
difficult to deal with as any operation involving `undefined`, including 
testing for equality, will also result in undefined.
- [Line 9](../config/openai.rego#L9): Calculates a boolean which is `true`
when the API key has been provided or false otherwise.
- [Lines 12 to 14](../config/openai.rego#12): Calculates the value of the bearer
token which will be provided to OpenAI.
- [Lines 17 to 20](../config/openai.rego#17): Defines what should happen when
the request is forwarded to OpenAI. Specifically it adds the `authorization`
header containing the API key.
- [Lines 25 to 30](../config/openai.rego#25): Defines the error message that will
be set if the OPENAI_API_KEY environment variable has not been configured. This
helps avoid confusing error messages from contacting OpenAI without the key.
- [Lines 33 to 41](../config/openai.rego#33): Is a function for generating the
error response when OpenAI's moderation policies are violated.
- [Lines 47 to 127](../config/openai.rego#47): Is a function for sending a 
moderation request to OpenAI and then collating any violations that cause
the content to be flagged.

### log.rego
The [`config/log.rego`](../config/log.rego) file ensures that sensitive information is
not logged.

- [Line 4]: Stops the `authorization` header being logged from input requests.
- [Line 5]: Stops the `authorization` header being logged in results.

## Component 3: the integrator authentication endpoint

The nodejs server provides an [`/authenticated`](../example-app/index.js#L56) 
endpoint which can be used to check if the caller is logged in. This is called 
by the application itself and by the Open Policy Agent in the `webapp.rego` script.

As this is an example application, this authentication component has been 
simplified to illustrate the allow and reject states, your final production 
configuration will need to be tailored to suit your applications production 
authentication requirements.

## Component 4: OpenAI moderations API

For more information on OpenAI's moderations endpoint please read their guide
on moderation.

[https://platform.openai.com/docs/guides/moderation](https://platform.openai.com/docs/guides/moderation)

## Component 5: OpenAI chat completions API

For more information on OpenAI's chat completions endpoint please read their
API docs.

[https://platform.openai.com/docs/api-reference/completions/create](https://platform.openai.com/docs/api-reference/completions/create)