# Ai Proxy reference docs

## Overview

This is a reference implementation showing developers how to integrate their TinyMCE application with the TinyMCE [plugin name].  This is not a production ready application and is to be used for demonstration and training purposes only.

Its recommended you review the OpenAi Proxy call flows diagram as it provides a high level overview of the interactions between the required components that enables the OpenAi suggestions feature.  The documentation will describe in more detail how to implement these interactions as a reference towards configuring your own solution.

## Main **Application with TinyMCE [Figure 1.0]**

The reference application is a simple nodejs server which serves a single page “Message of the Day” application. 

The NodeJS server has 6 endpoints:

- [`GET /`](../example-app/index.js#L52) - serves the application page.
- [`GET /ai-request.js`](../example-app/index.js#L53) - serves the ChatGPT shim.
- [`GET /authenticated`](../example-app/index.js#L56) - returns 200 for a logged in user and 403 for a logged out (unauthenticated) user.
- [`GET /message`](../example-app/index.js#L59) - serves the current message of the day.
- [`POST /message`](../example-app/index.js#L71) - updates the current message of the day.
- [`POST /login`](../example-app/index.js#L87) - authenticates a username/password and creates a session cookie so the users is logged-in.
- [`POST /logout`](../example-app/index.js#L104) - invalidates the session cookie so the user is logged-out

The application has 2 states: 

- Logged out - where the message of the day is displayed but can’t be edited, and
- Logged in - where a TinyMCE editor holds the current message of the day and can be used to edit it. While logged-in it is possible to use the AI plugin to query Chat GPT 3.5.

### ChatGPT shim

The AI plugin is agnostic to the AI provider allowing you to adapt different AI backends however to do that the integrator has to provide some code to adapt to the provider API. In the case of this example we are using ChatGPT 3.5.


In that code snippet we connect to ChatGPT via the envoy proxy running on [localhost](http://localhost) port 8080.

It is worth noting that we do not need to provide an API key for ChatGPT because that will be added by the envoy proxy.

## **Proxy [Figure 2.0]**

Envoy is used to proxy the requests after they are filtered by the Open Policy Agent (OPA).

## **Integrator Auth Endpoint [Figure 3.0]**

The nodejs server provides a `/authenticated` endpoint which can be used to check if the caller is logged in. This is called by 

…. As this is an example application, this authentication component has been simplified to illustrate the allow and reject states, your final production configuration will need to be tailored to suit your applications production authentication requirements.

## OpenAI Moderation API **[Figure 4.0]**

## **OpenAI Chat Completions API [Figure 5.0]**

## The flow Diagram

https://sequencediagram.org/