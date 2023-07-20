title OpenAI proxy call flows diagram

participant "Main Application with TinyMCE\nComponent 1" as TinyMCE
participant "Proxy\nComponent 2" as Proxy
participant "Integrator Auth Endpoint\nComponent 3" as Integrator Auth Endpoint
participant "OpenAI Moderation API\nComponent 4" as OpenAI Moderation API
participant "OpenAI Chat Completions API\nComponent 5" as OpenAI Chat Completions API


TinyMCE->Proxy: Chat completion request [Ref-1]
Proxy->Integrator Auth Endpoint: Allow this chat completion request? [Ref-2]
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request) [Ref-2.1]
Proxy->OpenAI Moderation API: Does this request pass the moderation standards? [Ref-3]
Proxy<--OpenAI Moderation API: No moderation flags - request would be accepted [Ref-3.1]
note over Proxy: Attach OpenAI API token to request
Proxy->OpenAI Chat Completions API: Chat completion request [Ref-4]
Proxy<--OpenAI Chat Completions API: Chat completion response [Ref-4.1]
TinyMCE<--Proxy: Chat completion response [Ref-1.1]

alt auth failure call flow
TinyMCE->Proxy: Chat completion request [Ref-1]
Proxy->Integrator Auth Endpoint: Allow this chat completion request? [Ref-2]
Proxy<--Integrator Auth Endpoint: 403 OK (Deny this request) [Ref-2.2]
TinyMCE<--Proxy: 403 Forbidden (failed authentication) [Ref-1.2]
end

alt moderation failure call flow
TinyMCE->Proxy: Chat completion request [Ref-1]
Proxy->Integrator Auth Endpoint: Allow this chat completion request? [Ref-2]
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request) [Ref-2.1]
Proxy->OpenAI Moderation API: Does this request pass the moderation standards? [Ref-3]
Proxy<--OpenAI Moderation API: Moderation flags triggered [Ref-3.2]
TinyMCE<--Proxy: 400 Bad Request (failed moderation) [Ref-1.3]
end
