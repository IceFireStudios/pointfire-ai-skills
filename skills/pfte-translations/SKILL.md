---
name: pfte-translations
description: 'Translate SharePoint pages and documents with PointFire Translator Express, check their translation status, and find the pages with missing or outdated translations, by driving the SharePoint site in a Chrome window. Use when asked to translate a SharePoint page, news post or document, list the languages of a SharePoint site, check whether translations are up to date, or refresh outdated translations, for example "translate https://contoso.sharepoint.com/sites/news/SitePages/Launch.aspx to French and German" or "which pages on the HR site have outdated translations?".'
compatibility: 'Requires the Chrome DevTools MCP server (chrome-devtools-mcp), Google Chrome and Node.js on the machine of the user, and PointFire Translator Express on the SharePoint site. Setup per AI tool: https://github.com/IceFireStudios/pfte-translations'
metadata:
  author: IceFire Studios
---

# PointFire Translator Express translations

PointFire Translator Express (PFTE) is a SharePoint app. On every modern SharePoint page where it runs, it exposes three tools to browser agents through `window.pfte.mcp`. This skill opens the SharePoint site in a Chrome window, asks the user to sign in the first time, and calls those tools by running script in the page.

| PFTE tool | What it does |
|---|---|
| `pointfire_translator_list_languages` | The site's source language and the languages it can translate into |
| `pointfire_translator_get_status` | Per language: up to date, outdated (the source changed since), or missing |
| `pointfire_translator_translate` | Translates a page, document or list item into one or more languages |

Input and result shapes: [references/tools.md](references/tools.md).

## Before you start

You need the browser tools of a **Chrome DevTools MCP server** (`chrome-devtools-mcp`): `list_pages`, `new_page`, `select_page`, `navigate_page` and `evaluate_script`. The setup of this skill names that server `pointfire-browser`, but any chrome-devtools MCP server works. Each AI tool puts its own prefix in front of the tool names (for example `mcp__pointfire-browser__evaluate_script`); go by the last part. When your tools load on demand, search for `evaluate_script` first.

When no such tools exist, stop. Tell the user the browser connection isn't set up, and point them to the setup instructions for their AI tool: https://github.com/IceFireStudios/pfte-translations#install

You need a **SharePoint URL**. When the user gave none, ask for the site, page or document URL. Don't guess a tenant.

## 1. Open the site

1. `list_pages`. When a tab is already on the same SharePoint host, `select_page` it, and `navigate_page` to the URL when it shows another page.
2. Otherwise `new_page` with the URL.

Keep the `pageId` and pass it to every later call. Pass `waitForStableDom: false` to every `evaluate_script` call of this skill.

## 2. Sign in (first time only)

SharePoint sends a browser without a session to the Microsoft sign-in page. Check where the tab ended up:

```js
() => ({ host: location.host, href: location.href })
```

When `host` is not the SharePoint host, for example `login.microsoftonline.com`, `login.microsoft.com`, `login.live.com`, or the organisation's own sign-in server:

1. Ask the user, and wait for the answer (use your question prompt when your tool has one): *"I opened `<tenant>.sharepoint.com` in a Chrome window and it shows the Microsoft sign-in page. Please sign in there, including any MFA prompt, until the SharePoint site shows."* Options: **Signed in** / **Cancel**.
2. After **Signed in**, check again. Still on a sign-in page → ask once more. **Cancel** → stop.

Rules:

- **Never** type, read, or ask for a user name, password, code or token. The user signs in in the Chrome window themselves.
- The Chrome window keeps its own profile, so the sign-in lasts across sessions. Expect the question again only when the session expired.
- A browser started with `--headless` can't show the sign-in page, and one started with `--isolated` forgets it at once. Tell the user to remove that flag.
- An *Access denied* or *Request access* page means the account has no access to the site. Report that and stop.

## 3. Wait for PointFire

PFTE loads a moment after the page. Wait up to 30 seconds:

```js
async () => {
  const start = Date.now();
  while (!window.pfte?.mcp && Date.now() - start < 30000) await new Promise((r) => setTimeout(r, 500));
  return { ready: !!window.pfte?.mcp, tools: window.pfte?.mcp?.tools?.map((t) => t.name) || [] };
}
```

`ready: false` means PFTE doesn't run on this page: it isn't installed or enabled for this site, or it's a classic page. Tell the user and stop; don't try to translate any other way.

After any navigation, a reload, or a new tab, wait for PFTE again before the next call. Opening a translation in another language can reload the page by itself.

## 4. Call a tool

Every result is `{ content: [{ type: 'text', text: '<json>' }], isError }`:

```js
async () => {
  const r = await window.pfte.mcp.callTool('pointfire_translator_get_status', { url: '<page or document URL>' });
  return { isError: !!r.isError, result: JSON.parse(r.content[0].text) };
}
```

- Call `pointfire_translator_list_languages` before translating, and only use its codes. `targetLanguages` **includes the source language**: never translate into `sourceLanguage.code`. "All languages" means every target except the source.
- Map the user's words to codes yourself ("French" → `fr-FR`). A name which matches no code: say so and list the closest ones.
- URLs may be absolute or server-relative.
- `isError: true` carries the reason in the JSON `error`. Report it; don't retry the same call.

## 5. Translate: start, then poll

A translation takes one to several minutes per item, too long for one script call. Start it and return at once; the job keeps running in the page:

```js
() => {
  const id = 'job-' + Date.now();
  window.__pfteJobs = window.__pfteJobs || {};
  window.__pfteJobs[id] = { state: 'running', startedAt: Date.now() };
  window.pfte.mcp
    .callTool('pointfire_translator_translate', { url: '<url>', targetLanguages: ['fr-FR', 'de-DE'] })
    .then(
      (r) => (window.__pfteJobs[id] = { state: 'done', isError: !!r.isError, result: r.content?.[0]?.text }),
      (e) => (window.__pfteJobs[id] = { state: 'failed', error: String(e?.message || e) })
    );
  return id;
}
```

Poll with the returned id. Each call waits up to 50 seconds in the page; call it again while `state` is `running`:

```js
async () => {
  const id = '<job id>';
  const start = Date.now();
  while (window.__pfteJobs?.[id]?.state === 'running' && Date.now() - start < 50000) await new Promise((r) => setTimeout(r, 1000));
  const job = window.__pfteJobs?.[id];
  if (!job) return { state: 'lost' };
  return { state: job.state, isError: job.isError, error: job.error, result: job.result ? JSON.parse(job.result) : undefined };
}
```

Rules:

- **Confirm before you translate.** Each language of each item is a paid job on the organisation's Azure Translator. Show what you will translate (items × languages) and ask first when it is more than 3 items or more than 5 languages.
- **Leave the tab alone while a job runs.** Navigating, reloading or closing it stops the job. Use another tab (`new_page`) when you need to look at something else.
- **One job at a time per tab.** Put every language for one item in a single call; translate several items one after the other.
- `state: 'lost'` means the page reloaded during the job. Run `get_status` and translate only the languages still `missing` or `outdated`.
- Repeating a translation is safe. Languages which are already up to date come back under `alreadyUpToDate` and aren't created again. Outdated languages are translated again in place.

Report to the user:

- Each new translation with its link from `translatedLanguages[].url`. **Never** build a translation URL yourself from the source URL and a language code.
- `alreadyUpToDate`, `skippedLanguages.unknown` / `.unsupported`, `errors`, and `status: 'completed_with_errors'` when present.

## Questions about a whole site or library

"Which pages have outdated translations?" has no single tool. List the source items with the SharePoint REST API from the same tab (it uses the signed-in session) and run `get_status` for each:

```js
async () => {
  const web = '/sites/<site>';                    // server-relative URL of the site
  const list = `${web}/SitePages`;                // or a library, e.g. `${web}/Shared Documents`
  const batch = [0, 25];                          // 25 items per call, about 1.5 s each
  const url = `${location.origin}${web}/_api/web/getList('${list}')/items?$select=Id,FileRef,Title,Source_x0020_ItemId&$filter=FSObjType eq 0&$top=500`;
  const res = await fetch(url, { headers: { Accept: 'application/json;odata=nometadata' } });
  if (!res.ok) return { error: res.status, body: await res.text() };
  const items = (await res.json()).value;
  // A translation points at its source through Source_x0020_Item; a source points at itself or at nothing.
  const sources = items.filter((i) => !i.Source_x0020_ItemId || i.Source_x0020_ItemId === i.Id);
  const report = [];
  for (const item of sources.slice(...batch)) {
    const r = await window.pfte.mcp.callTool('pointfire_translator_get_status', { url: item.FileRef });
    const s = JSON.parse(r.content[0].text);
    report.push({ url: item.FileRef, isError: !!r.isError, outdated: s.outdated?.map((l) => l.code), upToDate: s.upToDate?.map((l) => l.code), error: s.error });
  }
  return { sources: sources.length, report };
}
```

- Take the site URL from the URL you opened. Modern pages have no `_spPageContextInfo`.
- Use `getList('<server-relative list URL>')`, not `getByTitle`: list titles change with the site language.
- A 400 about `Source_x0020_Item` means PFTE never translated anything in that list. Query without the field and treat every item as a source.
- On a site with SharePoint's own multilingual pages, skip the items whose `_SPIsTranslation` is `Yes` when the list has that field.
- Run the next batch (`[25, 50]`, …) until `sources` is covered. More than 100 sources: say how many and confirm before checking them all.
- `upToDate` includes the source language itself; leave it out when counting translations.
- `missing` names every enabled language without a translation, often most of them. Report `outdated` per page, and `missing` only when the user asked for it.

## Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| The tab ends on a Microsoft sign-in page | Not signed in, or the session expired | Step 2 |
| `ready: false` after 30 seconds | PFTE isn't installed or enabled for the site, or it's a classic page | Tell the user to ask their SharePoint administrator |
| `state: 'lost'` while polling | The tab reloaded or navigated during the job | `get_status`, then translate what is left |
| `X is not defined` from a script | A SharePoint global which modern pages don't have | Use the URL you opened instead |
| The Chrome window doesn't open | Node.js or Chrome is missing, or another Chrome uses the same profile | Ask the user to install Node.js LTS and Chrome, or close that other Chrome window |
