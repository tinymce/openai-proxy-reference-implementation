# Open AI Proxy Reference Implementation

## Running instructions
1. Install Docker and Docker Compose.
2. Export environment variable, `OPENAI_API_KEY`, containing a Chat GPT 3.5 API key.
3. Run `docker compose up --build`.
4. Open `http://localhost:3000/`.
5. Login with username and password; both initially set to `admin`.
6. Press the AI button on TinyMCE’s toolbar and enter a prompt like _Suggest an inspiring quote by an astronaut._.
7. Replace the editor content with the suggested quote and style it as desired.
8. Press the Save button on TinyMCE’s toolbar.
9. Press the Logout button.
10. Admire the new message of the day.

## Description of components
See [docs/docs.md](docs/docs.md).