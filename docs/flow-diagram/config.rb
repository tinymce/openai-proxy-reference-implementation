title OpenAI proxy call flows diagram

participant "Main Application with TinyMCE\nComponent 1" as App
participant "Proxy\nComponent 2" as Proxy
participant "Integrator Auth Endpoint\nComponent 3" as AppServer
participant "OpenAI Moderation API\nComponent 4" as ModerationAPI
participant "OpenAI Chat Completions API\nComponent 5" as ChatCompletionsAPI

App->AppServer: Authorization token request [Ref-1]
App<-AppServer: Authorization token response [Ref-1.1]
note over App: Attach authorization token to request [Ref-2]
App->Proxy: Chat completion request [Ref-3]
note over Proxy: Verify Authorization [Ref-4a] [Ref-4b]
Proxy->ModerationAPI: Does this request pass the moderation standards? [Ref-5]
Proxy<--ModerationAPI: No moderation flags - request would be accepted [Ref-5.1]
note over Proxy: Attach OpenAI API token to request [Ref-6]
Proxy->ChatCompletionsAPI: Chat completion request [Ref-7]
Proxy<--ChatCompletionsAPI: Chat completion response
App<--Proxy: Chat completion response [Ref-3.1]

alt auth failure call flow
App->AppServer: Authorization token request [Ref-1]
App<-AppServer: Authorization token response [Ref-1.1]
note over App: Attach authorization token to request [Ref-2]
App->Proxy: Chat completion request [Ref-3]
note over Proxy: Verify Authorization [Ref-4a] [Ref-4b]
App<--Proxy: 403 Forbidden (failed authorization) [Ref-3.2a] [Ref-3.2b]
end

alt moderation failure call flow
App->AppServer: Authorization token request [Ref-1]
App<-AppServer: Authorization token response [Ref-1.1]
note over App: Attach authorization token to request [Ref-2]
App->Proxy: Chat completion request [Ref-3]
note over Proxy: Verify Authorization [Ref-4a] [Ref-4b]
Proxy->ModerationAPI: Does this request pass the moderation standards? [Ref-5]
Proxy<--ModerationAPI: Moderation flags triggered [Ref-5.2]
App<--Proxy: 400 Bad Request (failed moderation) [Ref-3.3]
end
