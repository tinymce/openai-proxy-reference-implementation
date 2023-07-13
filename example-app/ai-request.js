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
        // handler for messages received from ChatGPT 3.5
        onmessage: ({ data }) => {
          if (data !== '[DONE]') {
            const message = JSON.parse(data)?.choices[0]?.delta?.content;
            if (message) {
              streamMessage(message);
            }
          }
        },
        // handler for errors that occurred while attempting to contact ChatGPT 3.5
        onerror: (err) => {
          throw err; // stop and do not retry
        },
      }
    );
  })
}