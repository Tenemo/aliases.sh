## aliases.sh

[![Netlify Status](https://api.netlify.com/api/v1/badges/93940616-2c34-494c-815b-4fa1b98d6be3/deploy-status)](https://app.netlify.com/sites/aliases-sh/deploys)

[aliases.sh](https://aliases.sh)

A tiny static site that publishes my curated bash aliases and renders the real [aliases.sh](./aliases.sh) file with build-time syntax highlighting.

### How it works

- `index.html` contains the site metadata directly and uses an explicit placeholder for the aliases code block.
- `src/injectAliases.ts` inlines the Highlight.js theme and renders the real `aliases.sh` content at build/dev time.
- The built site is static and does not include runtime browser JavaScript.

### Local development

```bash
pnpm install
pnpm dev
pnpm test
pnpm build
```

### Notes

- `aliases.sh` itself is currently Bash-oriented. This repo does not guarantee zsh compatibility.
