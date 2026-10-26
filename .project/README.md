---
title: Project
description: What the .project folder is for, how it's laid out, how to add a new kind of record, and the front matter every note carries.
type: index
status: active
created: 2026-10-23
updated: 2026-10-26
---

# Project

The home for the information used to manage hello-kubernetes, kept with the code so people and agents find it in one place.

## Contents

- [GOAL.md](GOAL.md): what the project is for, and what's in and out of scope. Start here.
- [roadmap/1.x/](roadmap/1.x/README.md): research and plans for the current 1.x series.
- [roadmap/2.x/](roadmap/2.x/README.md): ideas for 2.0.
- [work/](work/README.md): one folder for each piece of work, named `YYYY-MM-DD-slug`, with a `plan.md` that gives the intent, the rules to follow and the validation to pass.

Each roadmap folder is freeform, with a README as its index. The notes explain *why* and *how*. What ships in which release is tracked in GitHub milestones and issues, which link back to the notes. A work plan connects the two: it lists the issues for a piece of work and links to the roadmap notes they implement.

The folder will grow to hold other project records, for example decision records, and the rules and conventions that agents follow.

## Adding a new kind of record

1. Create a folder for it at the top level, e.g. `decisions/`.
2. Add a `README.md` as its index, with `type: index` front matter, saying what the records are for and listing them.
3. Give every record the front matter below. If none of the existing `type` values fits, add one to the table, with its allowed `status` values.
4. Add the folder to [Contents](#contents).

## Front matter

Every note starts with flat YAML front matter: plain values and `[a, b]` lists only, no nesting, and quotes around any value containing `: `. That keeps it readable by simple scripts without a YAML library.

```yaml
---
title: Deployment
description: One line, used as the summary in the folder's README.
type: plan
status: active
areas: [deploy]
created: 2026-10-22
updated: 2026-10-23
---
```

| Field | Required | Values | What uses it |
|---|---|---|---|
| `title` | yes | Matches the page's `#` heading, without dates | Headings; the website if notes are ever published |
| `description` | yes | One sentence | The summary column in each folder's README |
| `type` | yes | `goal` · `index` · `review` · `plan` · `exploration` | Tells people and agents whether the page is a record or something to keep up to date. Roadmap plans and work plans (`work/*/plan.md`) both use `plan` |
| `status` | yes | `goal`, `index`: `active`<br>`review`: `final` (corrections only)<br>`plan`: `active` · `done` · `superseded`<br>`exploration`: `exploring` · `accepted` · `rejected` | Agents only work from `active` plans |
| `areas` | for `goal`, `review`, `plan`, `exploration` | `app` · `image` · `deploy` · `ci` · `site` · `operations` (the `area:` labels) | Finding the plan for an `area:` issue |
| `created` | yes | `YYYY-MM-DD` | When the note was written |
| `updated` | yes | `YYYY-MM-DD` | Date of the last real change, not link or formatting fixes |
| `issues` | no; for work plans | Issue numbers, e.g. `[56]` | Finding the issues a work plan delivers |
| `superseded_by` | when `status: superseded` | Path to the replacement note | Following a replaced plan to the current one |

When adding a note, add a row to its folder's README using the note's `description`. When a plan is done or replaced, change its `status` rather than deleting it.
