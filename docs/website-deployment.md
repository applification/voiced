# Website Deployment

The Voiced website lives in `website/` and is deployed to:

```text
https://voiced.applification.net
```

## Vercel CLI Deployment

This project currently uses Vercel CLI deployment rather than Git-based Vercel deployments.

Recommended Vercel project setting for CLI-only deployment:

```text
Root Directory: .
```

Then deploy from the website directory:

```sh
cd website
bun run build
vercel deploy --prod
```

If Vercel project settings use `Root Directory: website`, then deploy from the repository root instead:

```sh
vercel deploy --prod
```

Do not combine both `Root Directory: website` and running the CLI from `website/`. That makes Vercel look for `website/website` and fail with:

```text
The provided path ".../website/website" does not exist.
```

## Git Integration

Git-based Vercel deployment is intentionally not required for this project. If the Vercel project is connected to Git, Vercel may apply commit-author checks and block deployments when the local commit email is not associated with the expected Git account.

For CLI-only deployment, disconnect Git in the Vercel project settings:

```text
Project Settings > Git > Disconnect
```

## Upload Size Guardrail

The repository root contains a `.vercelignore` guardrail so an accidental root deploy does not upload macOS build products, archives, `node_modules`, or other large local artifacts.

Still, the preferred deployment command is from `website/` with Vercel `Root Directory: .`.

## Public Product URLs

Direct distribution and support use these website routes:

```text
Download: https://voiced.applification.net/download
Support: https://voiced.applification.net/support
Privacy: https://voiced.applification.net/privacy
```

The download route looks up the latest published GitHub Release and redirects to its ZIP asset, falling back to a DMG for older releases. `script/publish_release.sh` marks each local release as latest, so the public download updates automatically within the route's five-minute cache window.
