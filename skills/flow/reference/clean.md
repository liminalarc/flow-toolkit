# flow — normalize the index (`/flow --clean`)

Normalize the **index** (local mode):
- Status keyword per entry: `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- Entry format: `- **<id>** <Title> — \`STATUS\` — [detail](specs/<id>.md)`
- Every index entry links to an existing `specs/<id>.md`; every detail file is indexed; no duplicate ids.

Show a diff before writing. (In ado mode the board owns lifecycle — there's no local index to clean; use `/flow-lint` to check index↔detail integrity of the `specs/` dir.)
