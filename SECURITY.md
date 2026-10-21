# Security

Catification runs locally, never connects to the network and stores nothing outside its own preferences.
It reads the positions of other windows (not their titles or contents) and, only if you turn on
"Climb desktop icons", the positions of desktop icons through the Accessibility API.

## Reporting a vulnerability

Please report security problems privately through
[GitHub's private vulnerability reporting](https://github.com/Nikolsi/catification/security/advisories/new)
rather than in a public issue. You'll get a reply as soon as possible, usually within a few days.

## Verifying a download

Each release lists a `SHA256SUMS` file next to the zip. Check it with:

```bash
shasum -a 256 -c SHA256SUMS
```

Releases are built by GitHub Actions from the tagged commit; the build log is linked from the release.
