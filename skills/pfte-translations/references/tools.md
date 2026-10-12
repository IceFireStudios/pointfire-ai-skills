# PointFire tool reference

PointFire Translator Express registers these tools on every modern SharePoint page where it runs. Call them with `window.pfte.mcp.callTool(name, input)`; `window.pfte.mcp.tools` lists them with their input schemas.

Every result is `{ content: [{ type: 'text', text }], isError }`, where `text` is a JSON document. On an error the JSON holds an `error` message.

A language is always `{ name, code, localeId }`, for example `{ "name": "Français", "code": "fr-FR", "localeId": 1036 }`.

## `pointfire_translator_list_languages`

The site's source language and the languages it can translate into. Call it first to learn the valid codes.

**Input:** none.

```jsonc
{
  "sourceLanguage": { "name": "English", "code": "en-US", "localeId": 1033 },
  "isMultilingual": true,
  "targetLanguages": [
    { "name": "English", "code": "en-US", "localeId": 1033 },   // the source language is listed too: skip it
    { "name": "Français", "code": "fr-FR", "localeId": 1036 },
    { "name": "Deutsch", "code": "de-DE", "localeId": 1031 }
  ]
}
```

## `pointfire_translator_get_status`

Which languages of a page or document are up to date, outdated (the source changed after the translation), or missing.

**Input:**

| Field | Type | Required | Description |
|---|---|---|---|
| `url` | string | yes | Absolute or server-relative URL of the page or document |

```jsonc
{
  "url": "/sites/news/SitePages/Launch.aspx",      // the source item
  "translationType": "page",                       // "page" | "file" | "item"
  "sourceLanguage": { "name": "English", "code": "en-US", "localeId": 1033 },
  "upToDate": [                                    // includes the source language itself
    { "name": "Français", "code": "fr-FR", "localeId": 1036, "url": "https://contoso.sharepoint.com/sites/news/SitePages/Launch-fr.aspx" }
  ],
  "outdated": [ /* same shape, with url */ ],
  "missing":  [ /* no url: nothing exists yet */ ]
}
```

## `pointfire_translator_translate`

Translates a page, document or list item into one or more languages. The kind of item is detected from the URL. The call returns when the translation job is done, which takes one to several minutes per item.

**Input:**

| Field | Type | Required | Description |
|---|---|---|---|
| `url` | string | yes | Absolute or server-relative URL of the page or document |
| `targetLanguages` | string[] | yes | Language codes, for example `["fr-FR", "de-DE"]`. Short codes such as `"de"` are accepted |
| `sourceLanguage` | string | no | The language the content is written in, when it differs from what the item or site says |

```jsonc
{
  "status": "success",                             // or "completed_with_errors"
  "url": "/sites/news/SitePages/Launch.aspx",      // the source item
  "translationType": "page",
  "sourceLanguage": { "name": "English", "code": "en-US", "localeId": 1033 },
  "requestedLanguages": [ /* ... */ ],
  "translatedLanguages": [                         // a job ran for these
    { "name": "Français", "code": "fr-FR", "localeId": 1036, "url": "https://contoso.sharepoint.com/sites/news/SitePages/Launch-fr.aspx" }
  ],
  "alreadyUpToDate": [ /* skipped, with url */ ],
  "skippedLanguages": {
    "unknown": [],                                 // codes which aren't a language
    "unsupported": []                              // languages the site doesn't have
  },
  "errors": []
}
```

- Where a translation lands depends on the site setup, so read its location from `url`; never build it from the source URL. `url` is only missing when the translation couldn't be found back after the job.
- Languages which are already up to date are skipped and listed under `alreadyUpToDate`, so repeating a call doesn't create duplicates. Outdated languages are translated again in place.
- A second call for the same URL while one runs waits for the first to finish.
