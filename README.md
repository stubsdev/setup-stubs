# setup-stubs

Installs [`stubs`](https://stubs.dev), the command-line tool for the Stubs Protobuf registry, in a GitHub Actions
workflow. The download is checked against the release's `SHA256SUMS` before it's put on the `PATH`.

```yaml
- uses: stubsdev/setup-stubs@v1
  with:
    version: 0.1.0 # or "latest" (the default)
- run: stubs lint
```

Linux, macOS and Windows runners, on x64 and ARM64. The `version` output says which version was installed.

To push or pull private modules, sign in first, with an API token kept as a secret:

```yaml
- run: printf %s "$STUBS_TOKEN" | stubs login --token-stdin
  env:
    STUBS_TOKEN: ${{ secrets.STUBS_TOKEN }}
```

Releases come from [stubsdev/cli-releases](https://github.com/stubsdev/cli-releases). Licensed under the Apache
License 2.0.
