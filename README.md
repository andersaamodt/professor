# Professor

**Professor is an open policy and runtime for an AI teacher in the highest
sense of the word.** It aims for the field-trip audacity of a great science
teacher, the moral seriousness of a great humanist, the exacting care of a
great coach, and the humility of a scholar who can be corrected.

It is not a chatbot persona, a content firehose, a streak machine, or a claim to
academic credentials. “Professor” names an aspiration and a public standard.
The role it enacts is simply **the Teacher**.

Version 1.2 makes that aspiration operational:

- a constitutional, AI-facing teaching contract;
- an extensible catalog of pedagogical categories and tacks;
- an evidence- and ethics-gated self-improvement loop;
- a continuous pedagogical research practice with horizon scans, deep readings,
  contradiction tracking, and claim-level notes;
- a hard boundary between general policy, topic knowledge, and private learner
  state;
- a small local runtime for daily lesson packets and deliberate memory writes;
- a world-aware pop-music atlas built for one vivid musical encounter a day;
- a safe pattern for opt-in riddles, worlds, and ARGs;
- executable structural, privacy, state, scheduling, and cryptographic tests,
  plus adversarial teaching scenarios specified for host-level semantic evals.

The governing priority is:

> dignity, consent, safety, privacy, agency, and wellbeing → epistemic integrity
> → durable learning and transfer → learner authorship and independence →
> sustainable effort, wonder, and joy → engagement and spectacle

Engagement may be evidence that a lesson is alive. It is never permission to
manipulate.

## Start here

An AI should read [AGENTS.md](AGENTS.md), then [PROFESSOR.md](PROFESSOR.md).
Those documents tell it to **teach**, not recite the framework.

For a local installation:

```sh
bin/professor lint
bin/professor init
bin/professor daily --topic pop-music --minutes 12
bin/professor research --date 2026-08-10
```

`init` creates private state at `~/.professor` by default. Set
`PROFESSOR_DATA_DIR` to another external directory if needed. Professor refuses
to put private state inside the checkout, including through a symlink.
The marked `proposals/`, `plans/`, `campaigns/`, `keys/`, and `exports/`
subdirectories are reserved for Professor data; `memory forget --all --yes`
clears their contents while preserving unrecognized siblings at the data-home
root.

`daily` is passive and deterministic: it does not create state, consume missed
days as debt, or make an API call. It emits compact orientation for the host
LLM, not a lesson order. A schedule merely wakes Professor; the host applies the
current policy and judgment, begins with a brief invitation or object, and may
choose a different higher-value act. See
[`prompts/scheduled-fire.md`](prompts/scheduled-fire.md) for the consent and
no-backlog delivery contract.

`research` is likewise passive. It selects one bounded lane from the public
research agenda for a host with browsing or library access. The host records an
honest working note—distinguishing discovery, abstract screening, and full-text
reading—then proposes pedagogical changes separately. See
[`pedagogy/research/README.md`](pedagogy/research/README.md).

See every command with:

```sh
bin/professor help
```

## The living architecture

| Surface | Authority | May contain learner data? |
|---|---|---:|
| `PROFESSOR.md` | enacted teaching contract | No |
| `policies/registry.yaml` | stable normative policy propositions | No |
| `pedagogy/` | cross-topic categories, tacks, and scholarship | No |
| `pedagogy/research/` | public research agenda and claim notes | No |
| `topics/<id>/` | durable subject maps and media pointers | No |
| `prompts/` and `examples/` | derivative operating examples | No |
| `~/.professor/` | learner-owned memory, plans, proposals, campaigns | **Yes** |

The separation is architectural, not aspirational. The validator rejects
state-shaped files and media payloads in Git. The runtime rejects a data root
inside Git. Raw chats are not retained by default.

## A lesson has a pulse

Professor uses a flexible score rather than a script:

> **encounter → wager → model → make → test → echo**

The learner meets something worth caring about, commits a prediction, gains
just enough model to act, makes or judges something, proves learning through
retrieval or transfer, and leaves with a resonant connection or future cue.
Any beat can be tiny, combined, reordered, or omitted when the subject demands
it. The point is causality: something should change in what the learner can
notice, do, explain, question, or become.

## Self-improvement without self-corruption

Professor adapts on four deliberately separated timescales:

1. **In the moment:** change example, pace, representation, or scaffold.
2. **For this learner:** store an editable, expiring hypothesis outside Git,
   with provenance and contrary evidence.
3. **For this topic:** propose a reusable content or sequence improvement.
4. **For teaching generally:** propose a new category or tack, test it across
   contexts, and promote it through review.

For work that outlives a daily spark, Professor also has an external-only,
learner-owned expedition contract: [`templates/teaching-plan.yaml`](templates/teaching-plan.yaml)
and [`prompts/plan.md`](prompts/plan.md). It keeps only three near-term candidate
encounters concrete, rechecks them before use, prunes stale branches, keeps
distant routes porous, and includes a clean pause or retirement path.

The loop is:

> observation → scoped hypothesis → predicted benefit and harm → bounded trial
> → delayed evidence → private proposal → reviewed promotion or retirement

The ethical kernel cannot auto-amend. New techniques cannot promote themselves.
A method that raises completion while reducing autonomy, wellbeing,
accessibility, or truthfulness has failed.

## Pop music as a first expedition

The initial topic does not pretend there is one neutral “canon” or a linear
march from old to new. It builds **topographic hearing**: the ability to locate
a recording among scenes, technologies, migrations, markets, rhythmic
lineages, production choices, identities, and contested histories.

Each daily encounter pairs one historic period, scene, or microgenre with one
representative-but-not-definitive recording. The learner listens with a purpose,
makes a discrimination or creation, sees parent/sibling/descendant relations,
and later meets the feature again in another setting. No audio or lyric corpus
is stored here; media is linked lawfully and must have an accessible fallback.

Start with [topics/pop-music/README.md](topics/pop-music/README.md) and see an
enacted lesson in [examples/daily-pop-music.md](examples/daily-pop-music.md).

## Why Professor, not Teacher?

“Teacher” is the truer and larger vocation, but it is too generic for the
project. **Professor** is memorable, already names the repository, and carries
the productive tension this policy needs: scholarship must become professed
practice. The title grants no authority. Every claim remains inspectable, every
interpretation contestable, and the ultimate aim is a learner who needs the
Professor less.

## Verify and contribute

```sh
.tests/test.sh
```

New categories are welcome precisely because the catalog is incomplete. Follow
the promotion contract in `PROFESSOR.md`, use the templates, preserve scope
separation, and include counterevidence and retirement conditions—not just a
clever idea.

Professor is licensed under OWL 3.1. See [LICENSE](LICENSE).
