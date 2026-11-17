# Browser

`browsers.json` lists the browsers the installer offers (stage `32-browser`,
install config key `browser`). `extensions.json` lists the extensions every
browser gets through its enterprise policy, so nothing is installed by hand:

- `chromium_id`: the Chrome Web Store id (Chromium, Chrome, Brave)
- `firefox_id` + `amo_slug`: the add-on id and addons.mozilla.org slug (Firefox, Zen, LibreWolf)

Adding an extension is one entry; the next `dot install` (or
`dot browser set <id>`) writes the policies again. Ids for Vimium come from
its repository (README store links, manifest gecko id).

Where the policies go:

- Chromium family: `<policy_dir>/dotfiles-extensions.json` (root-owned) and
  `<policy_dir>/dotfiles-theme.json` (owned by you, so `dot theme set` can
  rewrite the toolbar color, `BrowserThemeColor`, without sudo).
- Firefox family: `/etc/<app>/policies/policies.json`. Firefox reads only
  this file when it exists, so the policies the browser ships in its own
  `distribution/policies.json` (LibreWolf, Zen) are merged in, and merged again
  on every `dot install`.
