// Use microsoft's fetch-event-source library to work around the 2000 character
// limit of the browser `EventSource` API
const fetchEventSourceModule = import("https://unpkg.com/@microsoft/fetch-event-source@2.0.1/lib/esm/index.js");

function ai_request(request, respondWith) {
  respondWith.stream(async (signal, streamMessage) => {
    // module to fetch the event stream from ChatGPT 3.5
    const { fetchEventSource } = await fetchEventSourceModule;
    // fetch an event stream from ChatGPT via the Envoy proxy
    return fetchEventSource(
      'http://localhost:8080/v1/chat/completions',
      {
        method: 'POST',
        // the authorization header containing the OpenAI API key is added by
        // the proxy so it does not need to be included in the client code
        headers: { 'Content-Type': 'application/json', },
        body: JSON.stringify({
          model: 'gpt-3.5-turbo',
          temperature: 0.7,
          max_tokens: 800,
          messages: [{ role: 'user', content: request.prompt }],
          stream: true
        }),
        openWhenHidden: true,
        signal,
        async onopen(response) {
          const contentType = response.headers.get('content-type');
          if (response.ok && contentType?.includes('text/event-stream')) {
            return; // everything's good
          } else if (contentType?.includes('application/json')) {
            throw new Error((await response.json())?.error?.message); // openai returns json on error
          } else {
            throw new Error(await response.text()); // OPA returns plain text
          }
        },
        // handler for messages received from ChatGPT 3.5
        onmessage({ data }) {
          if (data !== '[DONE]') {
            const message = JSON.parse(data)?.choices[0]?.delta?.content;
            if (message) {
              streamMessage(message);
            }
          }
        },
        // handler for errors that occurred while attempting to contact ChatGPT 3.5
        onerror(err) {
          throw err; // stop and do not retry
        },
      }
    );
  })
}