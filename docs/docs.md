# Ai Proxy reference docs

## Overview

This is a reference implementation showing how to integrate a TinyMCE application with the TinyMCE [AI Assistant](https://tiny.cloud/docs/tinymce/6/ai/).

It is *not* a production-ready application. It is for demonstration and training purposes only.

## First step

Review the OpenAi Proxy call flows diagram below.

It presents a high level overview of the interactions between the required components that enables the OpenAi suggestions feature.

The documentation following describes, in more detail, how to implement these interactions as a reference towards configuring your own solution.

![Diagram](flow-diagram/flowdiagram.svg)

## Component one: the main TinyMCE application

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
  
2. **Logged in**
  * a TinyMCE editor holds the current *Message of the day* and can be used to edit it.
  * While logged-in it is possible to use the AI plugin to query Chat GPT 3.5.

### ChatGPT shim

The AI plugin is agnostic to the AI provider, allowing you to adapt different AI backends.

To do this, the integrator has to adapt to the provider API.

This example uses ChatGPT 3.5.

```javascript
async function ai_request(request) {
  const resp = await fetch('http://localhost:8080/v1/chat/completions', {
    method: 'POST',
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      temperature: 0.7,
      max_tokens: 800,
      messages: [
        {
          role: 'user',
          content: request.prompt
        }
      ],
    })
  });
  if (resp.ok) {
    const data = await resp.json();
    return { type: 'string', data: data.choices[0].message.content.trim() };
  } else {
    const errorMessage = await resp.text();
    return Promise.reject(`Failed to communicate with the ChatGPT API: ${errorMessage}`);
  }
}

```

The above code snippet connects to ChatGPT via the envoy proxy running on [localhost:8080](http://localhost:8080).

**Note:** an API key for ChatGPT is not required here. It will be added by the envoy proxy. This also serves to hide the ChatGTP API key.

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

The [`envoy.yaml`](../config/envoy.yaml) file is heavily commented but here is an overview.

- Lines 1 to 5: Sets the port where the admin page is hosted. The admin page is useful
for debugging problems but it is strongly recommended that it not be made accessible
remotely as it makes available serveral destructive operations.
- Lines 8 to 16: Configures the proxy server to listen to connection requests on
port 8080. This is repeated for both IPv4 and IPv6 so that it will listen to 
connection attempts from both.
- Lines 28 to 29: Says that the proxy is not serving as multiple hosts but rather treats all incomming as to a single host.
- Lines 31 to 35: Tells the proxy to send everything that passes the filters and
that goes to the path /v1/ to the OpenAI cluster (defined later) on behalf of the client.
- Lines 37 to 50: Tells the proxy how to add CORS headers though it won't
actually do the addition of the headers until the related filter.
- Lines 52 to 62: Filters out requests to the health check "/ping" and handles 
it without passing the request onwards.
- Lines 63 to 72: Stores the path of the request in a lookup for a later filter.
- Lines 73 to 75: Adds the CORS headers using the previously defined rules (Lines 37 to 50).
- Lines 76 to 97: Runs the Open Policy Agent when the path matches /v1/ and filters
the requests based on running the rego scripts which are specified in opa.yaml.
- Lines 98 to 100: Runs the HTTP router which is required.
- Lines 102 to 115: Tells the proxy to define the OpenAI cluster as all IP addresses
returned by a DNS lookup on api.openai.com which should be contacted in a round-robin
fashion. It also specifies that the list of IP addresses should be regularly queried
to ensure changes are reflected.
- Lines 117 to 129: Tells the proxy to use TLS when contacting api.openai.com.

### opa.yaml
The [`opa.yaml`](../config/opa.yaml) file defines what the open policy agent does.

- Lines 1 to 4: Sets the port (9191) and path (`envoy/authz/allow`) for the remote procedure call. 
The `envoy/authz/allow` refers to the package `envoy.authz` and the variable `allow` defined in the file
[`authz.rego`](../config/authz.rego).
- Lines 5 and 6: Enables logging to the console.

## **Integrator Auth Endpoint [Component 3]**

The nodejs server provides an `/authenticated` endpoint which can be used to check if the caller is logged in. This is called by 

…. As this is an example application, this authentication component has been simplified to illustrate the allow and reject states, your final production configuration will need to be tailored to suit your applications production authentication requirements.

## OpenAI Moderation API **[Component 4]**

## **OpenAI Chat Completions API [Component  5]**

