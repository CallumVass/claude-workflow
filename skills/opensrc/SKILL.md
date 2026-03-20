---
name: opensrc
description: Fetch source code for any library into the project so the agent can reference implementation details. Works for any language — npm packages by name, or any GitHub repo (C#, Elixir, Python, Ruby, etc.) using owner/repo syntax. Use when the user wants to fetch source for a library, or when you need deeper context than types alone to understand how a package works internally. Replaces context7 for source fetching.
---

# opensrc

Fetch source code for libraries and GitHub repositories so you can reference actual implementations, not just types or docs. Works for **any language** — not just JavaScript.

## When to Use

- User asks to fetch/download source for any library or GitHub repo
- You need to understand how a library works internally (not just its API)
- User says "get the source for X" or "fetch X with opensrc"
- Types and docs aren't enough to answer a question about a package's behavior
- User wants to update fetched sources to match their installed versions

## Key Rule: npm name vs GitHub owner/repo

- **npm packages** (JS/TS only): use the bare package name — `opensrc zod`
- **Everything else** (C#, Elixir, Python, Ruby, Go, etc.): use `owner/repo` GitHub syntax — `opensrc xunit/xunit` or `opensrc Valian/live_vue`

Using an npm package name for a non-JS package will either fail or fetch the wrong thing.

## Quick Reference

```bash
# Fetch npm package by name (JS/TS — auto-detects version from lockfile)
npx opensrc zod
npx opensrc react react-dom next   # multiple at once
npx opensrc zod@3.22.0             # specific version

# Fetch any GitHub repo (works for ALL languages)
npx opensrc owner/repo                        # shorthand
npx opensrc github:owner/repo                 # explicit prefix
npx opensrc https://github.com/owner/repo     # full URL
npx opensrc owner/repo@v1.0.0                 # specific tag
npx opensrc owner/repo#main                   # specific branch

# Mix npm packages and GitHub repos in one command
npx opensrc zod xunit/xunit Valian/live_vue

# List all fetched sources
npx opensrc list

# Remove a source
npx opensrc remove zod
npx opensrc remove owner--repo
```

## File Modifications

On first run, opensrc asks permission to modify:
- `.gitignore` — adds `opensrc/` to prevent committing sources
- `tsconfig.json` — excludes `opensrc/` from compilation
- `AGENTS.md` — adds a section pointing agents to the sources

Skip the prompt with `--modify` or `--modify=false`:

```bash
npx opensrc zod --modify        # allow modifications
npx opensrc zod --modify=false  # deny modifications
```

## Output Structure

After fetching, sources live in `opensrc/`:

```
opensrc/
├── settings.json       # modification preferences
├── sources.json        # index of all fetched sources
└── zod/
    ├── src/
    ├── package.json
    └── ...
```

`sources.json` lists what's available:
```json
{
  "packages": [
    { "name": "zod", "version": "3.22.0", "path": "opensrc/zod" }
  ]
}
```

GitHub repos are stored as `opensrc/owner--repo/`.

## How to Use Fetched Source

After running opensrc, read source files directly:

```
opensrc/zod/src/         # Zod's source
opensrc/facebook--react/ # React's source (GitHub fetch)
```

Check `opensrc/sources.json` to see what's been fetched and at what version. Re-running `opensrc <package>` automatically updates to match the currently installed version.

## Fetching Specific Versions for Non-JS Languages

Since opensrc only auto-detects versions from JS lockfiles, you need to look up the version yourself for other languages and pass it as `owner/repo@<tag>`.

### Elixir — read `mix.lock`

```elixir
# mix.lock
%{
  "live_vue": {:hex, :live_vue, "0.3.4", "abc123...", [:mix], [], "hexpm", "..."},
  #                              ^^^^^^^  version is the 3rd element
}
```

```bash
npx opensrc Valian/live_vue@v0.3.4
```

### C# — read `.csproj`

```xml
<!-- MyApp.csproj -->
<PackageReference Include="xunit" Version="2.9.3" />
```

```bash
npx opensrc xunit/xunit@2.9.3
```

### Python — read `pyproject.toml`, `requirements.txt`, or `uv.lock` / `poetry.lock`

```toml
# pyproject.toml
[tool.poetry.dependencies]
httpx = "0.27.0"
```

```bash
npx opensrc encode/httpx@0.27.0
```

### Ruby — read `Gemfile.lock`

```
GEM
  specs:
    rails (7.2.1)
```

```bash
npx opensrc rails/rails@v7.2.1
```

### Tag format variations

opensrc handles some common normalizations (e.g. adding a `v` prefix), but repos vary. If you get a warning like `⚠ Could not find ref "...", cloned default branch instead`, check the actual tags on GitHub:

```bash
gh api repos/<owner>/<repo>/tags --jq '.[].name' | head -20
```

Then use the exact tag: `npx opensrc owner/repo@<exact-tag>`

## Tips

- **Any language**: Use `owner/repo` GitHub syntax for C#, Elixir, Python, Ruby, Go, or any non-JS library
- **Version auto-detection** (npm only): opensrc reads `package-lock.json`, `pnpm-lock.yaml`, or `yarn.lock` to find the exact installed version
- **Re-run to update**: Run the same command again to update an npm package to its newly installed version
- **Mix sources**: `npx opensrc zod xunit/xunit Valian/live_vue` fetches npm and GitHub repos together in one command
- **GitHub URL formats**: All of these work: `github:owner/repo`, `owner/repo`, `https://github.com/owner/repo`
