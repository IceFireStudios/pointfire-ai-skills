# PointFire AI skills

Skills and plugins that let AI agents, such as Claude Code, OpenAI Codex and GitHub Copilot, work with PointFire products.

| Skill | What it does |
|---|---|
| [`pfte-translations`](skills/pfte-translations/SKILL.md) | Translate SharePoint pages and documents with PointFire Translator Express, and find missing or outdated translations |

Ask your AI agent to translate SharePoint pages and documents with [PointFire Translator Express](https://pointfire.com), and to tell you which translations are missing or out of date.

```text
Translate https://contoso.sharepoint.com/sites/news/SitePages/Launch.aspx to French and German.
Which pages on https://contoso.sharepoint.com/sites/hr have outdated translations?
Refresh the outdated translations of that page.
Which languages can I translate into on https://contoso.sharepoint.com/sites/news?
```

> [!NOTE]
> This repository is private while we test it. You need read access to it to install or download anything below.

## What is it

PointFire Translator Express (PFTE) adds translation tools to every modern SharePoint page where it runs: list the site languages, check the translation status of a page or document, and translate it. This package teaches an AI agent to use them:

1. The agent opens your SharePoint site in a Chrome window of its own.
2. The first time, it asks you to sign in to Microsoft 365 in that window. It never sees or types your credentials.
3. It waits for PointFire to load on the page and calls its translation tools.

The translations are the same ones the "Translate now" panel creates, made with your organisation's PointFire license and Azure AI Translator.

The package has two parts:

| Part | What it does |
|---|---|
| The **`pfte-translations` skill** | The instructions: sign-in, language codes, starting and following a translation, site-wide status checks. It follows the open [Agent Skills](https://agentskills.io) format, so the same folder works in every tool below |
| The **`pointfire-browser` MCP server** | Google's [Chrome DevTools MCP server](https://github.com/ChromeDevTools/chrome-devtools-mcp), which lets the agent open and read SharePoint in Chrome. It's pinned to a tested version, uses its own Chrome profile, has its usage statistics turned off, and leaves out the tools this package doesn't need |

### Supported AI tools

| AI tool | Status |
|---|---|
| [Claude Code](#claude-code) | Supported, installs as a plugin |
| [OpenAI Codex](#openai-codex) (CLI, IDE extension, Codex in the ChatGPT desktop app) | Supported, being tested |
| [GitHub Copilot in VS Code](#github-copilot-in-vs-code) | Supported, being tested |
| Claude and ChatGPT on the web | Not possible: they can't start the browser connection on your machine |

## Prerequisites

- **PointFire Translator Express** installed on the SharePoint site, with a valid license and an Azure AI Translator connection configured
- A **Microsoft 365 account** with access to the site
- **Google Chrome**, current version
- **Node.js**, LTS version (20 or later), which runs the browser connection through `npx`
- One of the [supported AI tools](#supported-ai-tools)

## Install

### Claude Code

The plugin installs the skill and the browser connection together.

```bash
claude plugin marketplace add IceFireStudios/pointfire-ai-skills
claude plugin install pfte-translations@pointfire
```

Start a new Claude Code session, and ask a question like the ones at the top, or run `/pfte-translations:pfte-translations`.

### OpenAI Codex

1. Download `pfte-translations.zip` from the [latest release](https://github.com/IceFireStudios/pointfire-ai-skills/releases/latest), and unzip it into `~/.agents/skills/`, so you end up with `~/.agents/skills/pfte-translations/SKILL.md`.

   ```bash
   gh release download --repo IceFireStudios/pointfire-ai-skills --pattern pfte-translations.zip --dir /tmp
   mkdir -p ~/.agents/skills && unzip -o /tmp/pfte-translations.zip -d ~/.agents/skills
   ```

2. Add the browser connection:

   ```bash
   codex mcp add pointfire-browser -- npx -y chrome-devtools-mcp@1.10.1 "--userDataDir=$HOME/.pfte/chrome-profile" --no-usage-statistics --no-performance-crux --categoryInput=false --categoryEmulation=false --categoryPerformance=false --categoryNetwork=false --fileNavigations=false
   ```

3. Start a new Codex session, and ask a question like the ones at the top, or mention `$pfte-translations`.

### GitHub Copilot in VS Code

1. Download `pfte-translations.zip` from the [latest release](https://github.com/IceFireStudios/pointfire-ai-skills/releases/latest), and unzip it into `~/.copilot/skills/`, so you end up with `~/.copilot/skills/pfte-translations/SKILL.md`.
2. Run **MCP: Open User Configuration** from the Command Palette, and add the browser connection. Replace `<home>` with the full path of your home folder, for example `/Users/jane` or `C:/Users/jane`:

   ```json
   {
     "mcpServers": {
       "pointfire-browser": {
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "chrome-devtools-mcp@1.10.1",
           "--userDataDir=<home>/.pfte/chrome-profile",
           "--no-usage-statistics",
           "--no-performance-crux",
           "--categoryInput=false",
           "--categoryEmulation=false",
           "--categoryPerformance=false",
           "--categoryNetwork=false",
           "--fileNavigations=false"
         ]
       }
     }
   }
   ```

3. Open Copilot Chat in **Agent** mode, and ask a question like the ones at the top.

### Other AI tools

Any agent that reads Agent Skills and runs local MCP servers can use the package: put the `pfte-translations` folder from the zip in its skills folder, and add the browser connection with the command and arguments above. The Claude apps can also upload `pfte-translations.skill`, but the skill only works where the app can start the browser connection on your machine.

## The first time: sign in

The browser connection opens its own Chrome window, separate from your everyday Chrome. The first time the agent opens your SharePoint site there, it shows the Microsoft sign-in page. The agent stops and asks you to sign in in that window, with MFA where your organisation requires it.

The window keeps the sign-in in its own profile, so you aren't asked again until your organisation's session expires.

## Update

Check the [changelog](CHANGELOG.md) for what changed.

### Claude Code

```bash
claude plugin marketplace update pointfire
claude plugin update pfte-translations@pointfire
```

Restart Claude Code to load the new version.

### OpenAI Codex and GitHub Copilot

Download the new `pfte-translations.zip` from the [latest release](https://github.com/IceFireStudios/pointfire-ai-skills/releases/latest), and unzip it over the existing folder (`~/.agents/skills/` or `~/.copilot/skills/`). Start a new session.

When the changelog says the `chrome-devtools-mcp` version changed, update the version in your browser connection too. For Codex, run `codex mcp remove pointfire-browser` and add it again with the new command.

## What to know

- **Translations cost Translator credits.** Every language of every item is a job on your organisation's Azure AI Translator. The agent asks before translating more than 3 items or more than 5 languages at once.
- **Leave the Chrome window open** while a translation runs. One page takes one to several minutes. Closing the window, or navigating its tab, stops the translation.
- **The agent acts as you.** It works in a browser signed in with your account, so it can reach what you can reach in SharePoint. The skill limits it to the PointFire tools and SharePoint's REST API for listing pages.
- **Where the sign-in lives.** In Claude Code, the Chrome profile is in the plugin's data folder (`~/.claude/plugins/data/`), and uninstalling the plugin deletes it. For the other tools, it's `~/.pfte/chrome-profile`; delete that folder to sign out.

## Uninstall

| AI tool | Steps |
|---|---|
| Claude Code | `claude plugin uninstall pfte-translations@pointfire`, then `claude plugin marketplace remove pointfire` |
| OpenAI Codex | Delete `~/.agents/skills/pfte-translations`, run `codex mcp remove pointfire-browser`, and delete `~/.pfte` |
| GitHub Copilot | Delete `~/.copilot/skills/pfte-translations`, remove `pointfire-browser` from the MCP configuration, and delete `~/.pfte` |

## Troubleshooting

| What you see | What to do |
|---|---|
| The agent says PointFire doesn't run on the page | PFTE isn't installed or enabled for that site, or it's a classic page. Ask your SharePoint administrator |
| The agent says the browser connection isn't set up | Follow the install steps for your AI tool, then start a new session |
| The Chrome window doesn't open | Install Node.js LTS and Chrome. Close any other Chrome window that uses the same profile folder |
| You're asked to sign in again | Your organisation's session expired. Sign in once more in the Chrome window |

## Release a new version

For maintainers:

1. Change the skill in `skills/pfte-translations/` and, when needed, the browser connection in `.mcp.json`. Keep the `chrome-devtools-mcp` version and arguments in this README the same as in `.mcp.json`.
2. Set the new version in `.claude-plugin/plugin.json`. Claude Code only offers an update when this version changes.
3. Add a section for the version to `CHANGELOG.md`; it becomes the release notes.
4. Commit, then tag and push:

   ```bash
   git tag v0.2.0
   git push origin main --tags
   ```

The [Release workflow](.github/workflows/release.yml) validates the plugin and the skill, checks that the tag matches the version and the changelog, packages `pfte-translations.zip` and `pfte-translations.skill`, and publishes the GitHub release. Run the workflow by hand to build the packages without releasing them.
