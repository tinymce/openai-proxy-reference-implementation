// Use microsoft's fetch-event-source library to work around the 2000 character
// limit of the browser `EventSource` API
const fetchEventSourceModule = import("https://unpkg.com/@microsoft/fetch-event-source@2.0.1/lib/esm/index.js");

async function ai_request(request, streamMessage) {
  // module to fetch the event stream from ChatGPT 3.5
  const { fetchEventSource } = await fetchEventSourceModule;
  // the abort controller allows TinyMCE (or us) to end the stream early if needed
  const controller = new AbortController();
  // helper function to inform TinyMCE that the stream is complete and close the stream
  const streamDoneMessage = () => {
    controller.abort(); // close the stream
    streamMessage({ type: 'done', data: '' });
  };
  // helper function to inform TinyMCE that an error has occurred and close the stream
  const streamErrorMessage = (err) => {
    if (!controller.signal.aborted) { // check that the stream is not already closed
      streamMessage({ type: 'error', data: err });
      controller.abort(); // close the stream
    }
  }
  // handler for messages received from ChatGPT 3.5
  const onmessage = ({ data }) => {
    if (data === '[DONE]') {
      streamDoneMessage();
    } else {
      try {
        const jsonData = JSON.parse(data);
        const first = jsonData?.choices[0];
        const content = first?.delta?.content;
        if (content) {
          streamMessage({ type: 'message', data: content });
        } else if (first?.finish_reason === "stop") {
          streamDoneMessage(); // we only care about the first choice so end stream
        }
      } catch (err) {
        streamErrorMessage(err);
      }
    }
  };
  // handler for errors that occurred while attempting to contact ChatGPT 3.5
  const onerror = (err) => {
    streamErrorMessage('Network error');
    throw err; // stop and do not retry
  };
  // fetch an event stream from ChatGPT via the Envoy proxy
  fetchEventSource(
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
      signal: controller.signal,
      onmessage,
      onerror,
    }
  );
  return { type: 'stream', abort: controller.abort };
}