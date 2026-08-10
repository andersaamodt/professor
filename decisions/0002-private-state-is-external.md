# 0002 — Learner state never enters the checkout

Status: accepted in 1.0.0

## Decision

General pedagogy and topic knowledge may be public repository content. Learner
state, private proposals, campaign progress, solutions, and keys live only in an
external Professor data home. The runtime refuses a data path inside the
checkout even when Git would ignore it.

## Why

`.gitignore` prevents accidental tracking but does not prevent backups, tooling,
agents, searches, or later configuration from exposing private data. An
architectural boundary is smaller, more legible, and safer.

## Consequences

- `~/.professor` is the default; `PROFESSOR_DATA_DIR` is the only override.
- Read commands do not create it.
- Explicit writes use private modes.
- Tests use temporary external roots and private canaries.
