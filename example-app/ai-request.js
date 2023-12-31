// Use microsoft's fetch-event-source library to work around the 2000 character
// limit of the browser `EventSource` API
const fetchEventSourceModule = import("https://unpkg.com/@microsoft/fetch-event-source@2.0.1/lib/esm/index.js");

function ai_request(request, respondWith) {
  respondWith.stream(async (signal, streamMessage) => {
    // get a token to provide authorization [Ref-1]
    const jwtReq = await fetch('/jsonwebtoken');
    if (!jwtReq.ok) throw new Error('Not authenticated');
    const jwt = await jwtReq.text();
    // module to fetch the event stream from ChatGPT 3.5
    const { fetchEventSource } = await fetchEventSourceModule;
    // fetch an event stream from ChatGPT via the Envoy proxy [Ref-3]
    return fetchEventSource(
      'http://localhost:8080/v1/chat/completions',
      {
        method: 'POST',
        // the authorization header containing the OpenAI API key is added by
        // the proxy so it does not need to be included in the client code.
        // instead a JWT from the client is included to authorize with the proxy.
        headers: { 'Content-Type': 'application/json', authorization: `Bearer ${jwt}` }, // [Ref-2]
        body: JSON.stringify({
          model: 'gpt-3.5-turbo',
          temperature: 0.7, // controls the creativity, 0.7 is considered good for creative (non-factual) writing
          max_tokens: 800, // the maximum "cost" allowed for this API call
          messages: [{ role: 'user', content: request.prompt }],
          stream: true
        }),
        openWhenHidden: true, // continue processing while the browser window is hidden
        signal, // AbortController's AbortSignal
        // handler for the initial response to properly handle error messages
        async onopen(response) {
          const contentType = response.headers.get('content-type');
          if (response.ok && contentType?.includes('text/event-stream')) {
            return; // everything's good
          } else if (contentType?.includes('application/json')) { // [Ref-3.2b] [Ref-3.3]
            throw new Error((await response.json())?.error?.message); // openai returns json on error
          } else {
            throw new Error(await response.text()); // OPA returns plain text
          }
        },
        // handler for messages received from ChatGPT 3.5 [Ref-3.1]
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