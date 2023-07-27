title OpenAI proxy call flows diagram

participant "Main Application with TinyMCE\nComponent 1" as TinyMCE
participant "Proxy\nComponent 2" as Proxy
participant "Integrator Auth Endpoint\nComponent 3" as Integrator Auth Endpoint
participant "OpenAI Moderation API\nComponent 4" as OpenAI Moderation API
participant "OpenAI Chat Completions API\nComponent 5" as OpenAI Chat Completions API


TinyMCE->Proxy: Chat completion request <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L9>[Ref-1]</link>
Proxy->Integrator Auth Endpoint: Allow this chat completion request? <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L16>[Ref-2]</link>
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request) <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/index.js#L55>[Ref-2.1]</link>
Proxy->OpenAI Moderation API: Does this request pass the moderation standards? <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L20>[Ref-3]</link>
Proxy<--OpenAI Moderation API: No moderation flags - request would be accepted <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/openai.rego#L97>[Ref-3.1]</link>
note over Proxy: Attach OpenAI API token to request
Proxy->OpenAI Chat Completions API: Chat completion request <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L25>[Ref-4]</link>
Proxy<--OpenAI Chat Completions API: Chat completion response [Ref-4.1]
TinyMCE<--Proxy: Chat completion response <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L37>[Ref-1.1]</link>

alt auth failure call flow
TinyMCE->Proxy: Chat completion request <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L9>[Ref-1]</link>
Proxy->Integrator Auth Endpoint: Allow this chat completion request? <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L16>[Ref-2]</link>
Proxy<--Integrator Auth Endpoint: 403 OK (Deny this request) <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/index.js#L55>[Ref-2.2]</link>
TinyMCE<--Proxy: 403 Forbidden (failed authentication) <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/webapp.rego#L7>[Ref-1.2a]</link> <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L31>[Ref-1.2b]</link>
end

alt moderation failure call flow
TinyMCE->Proxy: Chat completion request <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L9>[Ref-1]</link>
Proxy->Integrator Auth Endpoint: Allow this chat completion request? <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L16>[Ref-2]</link>
Proxy<--Integrator Auth Endpoint: 200 OK (Allow this request) <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/index.js#L55>[Ref-2.1]</link>
Proxy->OpenAI Moderation API: Does this request pass the moderation standards? <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/authz.rego#L20>[Ref-3]</link>
Proxy<--OpenAI Moderation API: Moderation flags triggered <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/config/openai.rego#L97>[Ref-3.2]</link>
TinyMCE<--Proxy: 400 Bad Request (failed moderation) <link:https://github.com/tinymce/openai-proxy-reference-implementation/blob/main/example-app/ai-request.js#L31>[Ref-1.3]</link>
end
