title OpenAI proxy call flows diagram

participant "Main Application with TinyMCE\nComponent 1" as App
participant "Proxy\nComponent 2" as Proxy
participant "Integrator Auth Endpoint\nComponent 3" as AppServer
participant "OpenAI Moderation API\nComponent 4" as ModerationAPI
participant "OpenAI Chat Completions API\nComponent 5" as ChatCompletionsAPI

App->AppServer: Authorization token request <link:/example-app/ai-request.js#L7>[Ref-1]</link>
App<-AppServer: Authorization token response <link:/example-app/index.js#L56>[Ref-1.1]</link>
note over App: Attach authorization token to request <link:/example-app/ai-request.js#L21>[Ref-2]</link>
App->Proxy: Chat completion request <link:/example-app/ai-request.js#L13>[Ref-3]</link>
note over Proxy: Verify Authorization <link:/config/authz.rego#L16>[Ref-4a]</link> <link:/config/webapp.rego#L16>[Ref-4b]</link>
Proxy->ModerationAPI: Does this request pass the moderation standards? <link:/config/authz.rego#L20>[Ref-5]</link>
Proxy<--ModerationAPI: No moderation flags - request would be accepted <link:/config/openai.rego#L97>[Ref-5.1]</link>
note over Proxy: Attach OpenAI API token to request <link:/config/openai.rego#L16>[Ref-6]</link>
Proxy->ChatCompletionsAPI: Chat completion request <link:/config/authz.rego#L25>[Ref-7]</link>
Proxy<--ChatCompletionsAPI: Chat completion response
App<--Proxy: Chat completion response <link:/example-app/ai-request.js#L42>[Ref-3.1]</link>

alt auth failure call flow
App->AppServer: Authorization token request <link:/example-app/ai-request.js#L7>[Ref-1]</link>
App<-AppServer: Authorization token response <link:/example-app/index.js#L56>[Ref-1.1]</link>
note over App: Attach authorization token to request <link:/example-app/ai-request.js#L21>[Ref-2]</link>
App->Proxy: Chat completion request <link:/example-app/ai-request.js#L13>[Ref-3]</link>
note over Proxy: Verify Authorization <link:/config/authz.rego#L16>[Ref-4a]</link> <link:/config/webapp.rego#L16>[Ref-4b]</link>
App<--Proxy: 403 Forbidden (failed authentication) <link:/config/webapp.rego#L9>[Ref-3.2a]</link> <link:/example-app/ai-request.js#L36>[Ref-3.2b]</link>
end

alt moderation failure call flow
App->AppServer: Authorization token request <link:/example-app/ai-request.js#L7>[Ref-1]</link>
App<-AppServer: Authorization token response <link:/example-app/index.js#L56>[Ref-1.1]</link>
note over App: Attach authorization token to request <link:/example-app/ai-request.js#L21>[Ref-2]</link>
App->Proxy: Chat completion request <link:/example-app/ai-request.js#L13>[Ref-3]</link>
note over Proxy: Verify Authorization <link:/config/authz.rego#L16>[Ref-4a]</link> <link:/config/webapp.rego#L16>[Ref-4b]</link>
Proxy->ModerationAPI: Does this request pass the moderation standards? <link:/config/authz.rego#L20>[Ref-5]</link>
Proxy<--ModerationAPI: Moderation flags triggered <link:/config/openai.rego#L97>[Ref-5.2]</link>
App<--Proxy: 400 Bad Request (failed moderation) <link:/example-app/ai-request.js#L36>[Ref-3.3]</link>
end
