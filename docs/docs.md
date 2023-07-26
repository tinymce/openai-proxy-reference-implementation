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
| [`GET /`](../example-app/index.js#L50)              | ../example-app/index.js#L50  | Serves the application page.                                                              |
| [`GET /ai-request.js`](../example-app/index.js#L51) | ../example-app/index.js#L51  | Serves the ChatGPT shim.                                                                  |
| [`GET /authenticated`](../example-app/index.js#L54) | ../example-app/index.js#L54  | Returns 200 for a logged in user and 403 for a logged out (unauthenticated) user.         |
| [`GET /jsonwebtoken`](../example-app/index.js#L57) | ../example-app/index.js#L57  | Serves a JSON Web Token containing the authorized capabilties of the authenticated user. This makes use of a secret shared between the example-app and the proxy, stored in the environment variable `EXAMPLE_APP_JWT_SECRET`, to sign the JWT.         |
| [`GET /message`](../example-app/index.js#L77)       | ../example-app/index.js#L77  | Serves the current message of the day.                                                    |
| [`POST /message`](../example-app/index.js#L89)      | ../example-app/index.js#L89  | Updates the current message of the day.                                                   |
| [`POST /login`](../example-app/index.js#L105)        | ../example-app/index.js#L105  | authenticates a username/password and creates a session cookie so the users is logged-in. |
| [`POST /logout`](../example-app/index.js#L122)      | ../example-app/index.js#L122 | Invalidates the session cookie so the user is logged-out.


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

To do this, the integrator must adapt to the provider API.

This example uses ChatGPT 3.5.

| line(s)                                            | purpose                                                                                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [Line 3](../example-app/ai-request.js#L3)          | Loads the FetchEventSource library. This works around the 2,000 character limitation of the browser’s built-in EventSource API. |
| [Line 5](../example-app/ai-request.js#L5)          | The generic interface TinyMCE provides. The `request` parameter includes the text of the request in `request.prompt`. The `respondWith` parameter provides adapters to different situations. In this case `respondWith.stream` is used to get access to streaming-related values. |
| [Line 6](../example-app/ai-request.js#L6)          | The `stream` option gives us access to `signal` which is an [AbortSignal](https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal) and `streamMessage` which is a simple callback that takes a string to be added on to the existing content. |
| [Lines 8 to 10](../example-app/ai-request.js#L8)   | Request a JSON Web Token that can prove to the proxy server that the user is authorised to make AI requests. |
| [Lines 12 to 14](../example-app/ai-request.js#L12)  | Get the FetchEventSource module and immedately call it. |
| [Line 15](../example-app/ai-request.js#L15)        | Specifies the proxy URL used to proxy all OpenAI requests. The example code connects to ChatGPT via the envoy proxy running on [localhost:8080](http://localhost:8080). |
| [Line 17](../example-app/ai-request.js#L17)        | Specifies that the stream should be started by making a `POST` request so a `body` can be included. |
| [Line 21](../example-app/ai-request.js#L21)        | Specifies, using the `content-type` header, that the `body` will contain JSON and includes the JWT to authorize the request with envoy.  <br/>**Note**: the `authorization` header does not include the OpenAI API key. This `authorization` header will be replaced by the envoy proxy to use the OpenAI API key before it is forwarded to OpenAI. This allows it to be hidden from end users. |
| [Lines 22 to 28](../example-app/ai-request.js#L22) | Configures ChatGPT settings, including: the model used; the creativity; the maximum output length; the question posed: and that the reply should be streamed. |
| [Line 29](../example-app/ai-request.js#L29)        | Ensures the request is not canceled if the user switches away from the browser window. |
| [Line 30](../example-app/ai-request.js#L30)        | Sets the AbortSignal so TinyMCE can signal to the FetchEventSource call that it should be canceled if the user closes the AI window early. |
| [Lines 32 to 41](../example-app/ai-request.js#L32) | Specifies how to handle the initial connection response. By default, the FetchEventStream will report a generic error if the response type is not `text/event-stream`. OpenAI uses JSON to communicate error messages; so this method is needed to extract error messages so they can be provided to the end user. |
| [Lines 43 to 50](../example-app/ai-request.js#L43) | Converts the JSON messages from OpenAI into the `streamMessage` calls that take the content string. |
| [Lines 52 to 54](../example-app/ai-request.js#L52) | Rethrows any errors to abort processing. |

## Component 2: the proxy server

Envoy is used to proxy the requests after they are filtered by the Open Policy Agent (OPA).

This makes use of these two container images from Docker Hub:

* [envoyproxy/envoy](https://hub.docker.com/r/envoyproxy/envoy)
* [openpolicyagent/opa](https://hub.docker.com/r/openpolicyagent/opa).

These both use configuration files in the `/config/` folder:

* [`envoy.yaml`](../config/envoy.yaml) configures the Envoy proxy
* [`opa.yaml`](../config/opa.yaml) configures the Open Policy Agent.

The Open Policy Agent also makes use of the Rego files to script the process of authenticating and moderating the requests to be sent to OpenAI.

### envoy.yaml

The [`config/envoy.yaml`](../config/envoy.yaml) file is heavily commented but here is an overview.

| lines                                         | purpose                                                                                                                                                                     |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Lines 1 to 5](../config/envoy.yaml#L1)       | Sets the port where the admin page is hosted. The admin page is useful for debugging problems but it is strongly recommended that it not be made accessible remotely as it makes available serveral destructive operations. |
| [Lines 8 to 16](../config/envoy.yaml#L8)      | Configures the proxy server to listen to connection requests on port 8080. This is repeated for both IPv4 and IPv6 so that it will listen to connection attempts from both. |
| [Lines 28 to 29](../config/envoy.yaml#L28)    | Says that the proxy is not serving as multiple hosts but rather treats all incomming as to a single host.                                                                   |
| [Lines 31 to 36](../config/envoy.yaml#L31)    | Tells the proxy to send everything that passes the filters and that goes to the path /v1/ to the OpenAI cluster (defined later) on behalf of the client.                    |
| [Lines 38 to 51](../config/envoy.yaml#L38)    | Tells the proxy how to add CORS headers though it won't actually do the addition of the headers until the related filter.                                                   |
| [Lines 53 to 63](../config/envoy.yaml#L53)    | Filters out requests to the health check "/ping" and handles it without passing the request onwards.                                                                        |
| [Lines 64 to 73](../config/envoy.yaml#L64)    | Stores the path of the request in a lookup for a later filter.                                                                                                              |
| [Lines 74 to 76](../config/envoy.yaml#L74)    | Adds the CORS headers using the previously defined rules (Lines 37 to 50).                                                                                                  |
| [Lines 77 to 98](../config/envoy.yaml#L77)    | Runs the Open Policy Agent when the path matches /v1/ and filters the requests based on running the rego scripts which are specified in opa.yaml.                           |
| [Lines 99 to 101](../config/envoy.yaml#L99)   | Runs the HTTP router which is required.                                                                                                                                     |
| [Lines 103 to 116](../config/envoy.yaml#L103) | Tells the proxy to define the OpenAI cluster as all IP addresses returned by a DNS lookup on api.openai.com which should be contacted in a round-robin fashion. It also specifies that the list of IP addresses should be regularly queried to ensure changes are reflected. |
| [Lines 118 to 130](../config/envoy.yaml#L118) | Tells the proxy to use TLS when contacting api.openai.com.                                                                                                                  |


### opa.yaml

The [`config/opa.yaml`](../config/opa.yaml) file defines what the open policy agent does.

| line(s)                                | purpose                         |
| -------------------------------------- | ------------------------------- |
| [Lines 1 to 4](../config/opa.yaml#L1)  | Sets the port (9191) and path (`envoy/authz/allow`) for the remote procedure call. The `envoy/authz/allow` refers to the package `envoy.authz` and the variable `allow` defined in the file |
| [`authz.rego`](../config/authz.rego)   |                                 |
| [Lines 5 and 6](../config/opa.yaml#L5) | Enables logging to the console. |

### authz.rego
The [`config/authz.rego`](../config/authz.rego) file is the entrypoint for checking
the requests. 

| line(s)                                     | purpose                                                                                          |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| [Line 4](../config/authz.rego#L4)           | The HTTP request data is imported so it can be checked before forwarding. The import is renamed `http_request` to avoid being confused with the `http.send(...)` function. |
| [Line 5](../config/authz.rego#L5)           | Functions and variables are imported from `openai.rego`.                                         |
| [Line 6](../config/authz.rego#L6)           | Functions and variables are imported from `webapp.rego`.                                         |
| [Lines 11 to 13](../config/authz.rego#L11)  | OPTIONS requests are approved so that any CORS preflight requests complete.                      |
| [Lines 16 and 17](../config/authz.rego#L16) | User authorization is checked. See `webapp.rego` for details.                                   |
| [Lines 18 and 19](../config/authz.rego#L18) | The server configuration environment variable `OPENAI_API_KEY` existence is checked. This ensures a less confusing error message; it is not essential for a production implementation. |
| [Lines 20 to 24](../config/authz.rego#L20)  | Any POST requests going to the completion endpoint are moderated. See `openai.rego` for details. |
| [Line 25](../config/authz.rego#L25)         | All checks passed: the request is forwarded to OpenAI.                                           |

### webapp.rego
The [`config/webapp.rego`](../config/webapp.rego) file contains the logic for checking
if the client is authenticated along with the reply that is sent when authentication fails.

| line(s)                                     | purpose                                                                                          |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| [Line 6](../config/webapp.rego#L6)   | Reads the environment variable, `EXAMPLE_APP_JWT_SECRET`, into a variable with the default value `"Default JWT secret"`. The same default is used on the example app for ease of configuration. In a production quality application, however, this should always be set from the environment variable. |
| [Lines 9 to 14](../config/webapp.rego#L9)   | Defines the error message sent if request authentication fails. |
| [Lines 17 to 34](../config/webapp.rego#L17) | Checks to see if the request contained a valid JSON Web Token which authorizes the user to use the OpenAI chat completions API. This makes use of a secret shared between the example app and the proxy to check that the JWT is valid. |

### openai.rego

The [`config/openai.rego`](../config/openai.rego) file contains

* the logic for querying the moderation endpoint of OpenAI; and
* the messages that should be sent.

| line(s)                                      | purpose                                                                                                                                                                                          |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Line 6](../config/openai.rego#L6)           | Reads the environment variable `OPENAI_API_KEY` into a variable with the default value `null`. The default is important because otherwise the value will be `undefined` which is very difficult to deal with as any operation involving `undefined`, including testing for equality, will also result in undefined. |
| [Line 9](../config/openai.rego#L9)           | Calculates a boolean which is `true` when the API key has been provided or false otherwise.                                                                                                      |
| [Lines 12 to 14](../config/openai.rego#L12)  | Calculates the value of the bearer token which will be provided to OpenAI.                                                                                                                       |
| [Lines 17 to 20](../config/openai.rego#L17)  | Defines what should happen when the request is forwarded to OpenAI. Specifically it adds the `authorization` header containing the API key.                                                      |
| [Lines 25 to 30](../config/openai.rego#L25)  | Defines the error message that will be set if the OPENAI_API_KEY environment variable has not been configured. This helps avoid confusing error messages from contacting OpenAI without the key. |
| [Lines 33 to 41](../config/openai.rego#L33)  | Is a function for generating the error response when OpenAI's moderation policies are violated.                                                                                                  |
| [Lines 47 to 127](../config/openai.rego#L47) | Is a function for sending a moderation request to OpenAI and then collating any violations that cause the content to be flagged.                                                                 |

### log.rego

The [`config/log.rego`](../config/log.rego) file ensures that sensitive information is not logged.

| line                            | purpose                                                            |
| ------------------------------- | ------------------------------------------------------------------ |
| [Line 4](../config/log.rego#L4) | Stops the `authorization` header being logged from input requests. |
| [Line 5](../config/log.rego#L5) | Stops the `authorization` header being logged in results.          |

## Component 3: the integrator authentication endpoint

The nodejs server provides a [`/jsonwebtoken`](../example-app/index.js#L57) endpoint which can be used to generate a signed JSON Web Token authorizing the request.

This is called by the example-app and then included in the `authorization` header
with the request to the envoy proxy.

The envoy proxy then [validates this JWT](../config/webapp.rego#L25) as part of
the request processing. This ensures the caller is authorized before forwarding
the request to OpenAI.

Alternatively, implement this by passing the session cookie to the proxy and
having the proxy call the `/authenticated` endpoint.

In this example application, the authentication component has been simplified to
illustrate the allow and reject states. For example, a dummy database with
hardcoded credentials is used instead of a real database. As well, the JWT is
signed with a shared secret rather than a public/private certificate pair.

A production configuration must be tailored to the application’s production authentication requirements.

## Component 4: OpenAI moderations API

For more information on OpenAI’s moderations endpoint see their moderation guide: [https://platform.openai.com/docs/guides/moderation](https://platform.openai.com/docs/guides/moderation).

## Component 5: OpenAI chat completions API

For more information on OpenAI's chat completions endpoint see their API documentation: [https://platform.openai.com/docs/api-reference/completions/create](https://platform.openai.com/docs/api-reference/completions/create).
