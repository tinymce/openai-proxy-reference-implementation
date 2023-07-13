title OpenAI proxy call flows diagram

participant "Main Application with TinyMCE\nFigure 1.0" as TinyMCE
participant "Proxy\nFigure 2.0" as Proxy
participant "Integrator Auth Endpoint\nFigure 3.0" as Integrator Auth Endpoint
participant "OpenAI Moderation API\nFigure 4.0" as OpenAI Moderation API
participant "OpenAI Chat Completions API\nFigure 5.0" as OpenAI Chat Completions API


TinyMCE->Proxy: Chat completion request
Proxy->Integrator Auth Endpoint: Allow this chat completion request?
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request)
Proxy->OpenAI Moderation API: Does this request pass the moderation standards?
Proxy<--OpenAI Moderation API: No moderation flags - request would be accepted
note over Proxy: Attach OpenAI API token to request
Proxy->OpenAI Chat Completions API: Chat completion request
Proxy<--OpenAI Chat Completions API: Chat completion response
TinyMCE<--Proxy: Chat completion response

opt auth failure call flow
TinyMCE->Proxy: Chat completion request
Proxy->Integrator Auth Endpoint: Allow this chat completion request?
Proxy<--Integrator Auth Endpoint: 403 OK (Deny this request)
TinyMCE<--Proxy: 403 Forbidden (failed authentication)
end

opt moderation failure call flow
TinyMCE->Proxy: Chat completion request
Proxy->Integrator Auth Endpoint: Allow this chat completion request?
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request)
Proxy->OpenAI Moderation API: Does this request pass the moderation standards?
Proxy<--OpenAI Moderation API: Moderation flags triggered
TinyMCE<--Proxy: 400 Bad Request (failed moderation)
end