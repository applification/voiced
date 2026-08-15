# Voiced website

The public website for Voiced, a private macOS dictation and capture utility.

The site reflects the current app workflow:

- Right Command dictates into the previously focused editor.
- Shift + Right Command saves a voice capture to Inbox.
- Double Shift saves selected text.
- Option-Space opens the persistent Inbox and Done shelf.
- Captures can be edited, searched, refined with preview and undo, copied, dragged, moved, or removed.
- Local WhisperKit models are downloaded only after explicit approval.

## Run locally

```sh
bun install
bun run dev
```

Open `http://localhost:3000`.

## Verify

```sh
bun run lint
bun run build
```

## Public routes

- `/` product site
- `/download` latest GitHub release package
- `/support` setup and troubleshooting help
- `/privacy` privacy policy

Deployment details live in `../docs/website-deployment.md`.
