#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
professor="$repo_root/bin/professor"
professor_test_root=$(mktemp -d "${TMPDIR:-/tmp}/professor-tests.XXXXXX")
professor_test_data="$professor_test_root/private-data"
failure_output="$professor_test_root/expected-failure.out"
status_before=$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)

cleanup() {
  rm -rf -- "$professor_test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf '%s\n' "test failure: $*" >&2
  exit 1
}

assert_contains() {
  pattern=$1
  path=$2
  grep -F -- "$pattern" "$path" >/dev/null 2>&1 || fail "$path does not contain: $pattern"
}

assert_not_contains() {
  pattern=$1
  path=$2
  if grep -F -- "$pattern" "$path" >/dev/null 2>&1; then
    fail "$path unexpectedly contains: $pattern"
  fi
}

expect_fail() {
  if "$@" >"$failure_output" 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}

mode_of() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

digest_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

digest_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

state_digest() {
  root=$1
  find "$root" -type f -print | sort | while IFS= read -r file; do
    printf '%s\n' "${file#"$root"}"
    digest_file "$file"
  done | digest_stream
}

export PROFESSOR_DATA_DIR="$professor_test_data"

"$professor" lint >"$professor_test_root/lint.out"
assert_contains 'Professor validation passed' "$professor_test_root/lint.out"

# Passive commands are pure even before state exists.
[ ! -e "$professor_test_data" ] || fail 'test data unexpectedly exists before passive reads'
"$professor" state-path >"$professor_test_root/state-path.out"
"$professor" daily --topic pop-music --date 2026-08-10 --minutes 9 >"$professor_test_root/daily-a.out"
"$professor" daily --topic pop-music --date 2026-08-10 --minutes 9 >"$professor_test_root/daily-b.out"
cmp "$professor_test_root/daily-a.out" "$professor_test_root/daily-b.out" >/dev/null || fail 'daily brief is not deterministic'
"$professor" lecture --minutes 4 'why eclipses have seasons' >"$professor_test_root/lecture-a.out"
"$professor" lecture --minutes 4 'why eclipses have seasons' >"$professor_test_root/lecture-b.out"
cmp "$professor_test_root/lecture-a.out" "$professor_test_root/lecture-b.out" >/dev/null || fail 'lecture brief is not deterministic'
"$professor" lecture --minutes 1 --plain -- '-leading-dash subject' >"$professor_test_root/lecture-plain.out"
"$professor" research --date 2026-08-19 >"$professor_test_root/research-a.out"
"$professor" research --date 2026-08-19 >"$professor_test_root/research-b.out"
cmp "$professor_test_root/research-a.out" "$professor_test_root/research-b.out" >/dev/null || fail 'research brief is not deterministic'
[ ! -e "$professor_test_data" ] || fail 'passive commands created state'
assert_contains 'Private-state mutation: none' "$professor_test_root/daily-a.out"
assert_contains 'Missed-day debt: none' "$professor_test_root/daily-a.out"
assert_contains 'Complete core: 4 minutes' "$professor_test_root/lecture-a.out"
assert_contains 'Presentation: standalone-system-tour' "$professor_test_root/lecture-a.out"
assert_contains 'preflight Firefox and use it by default' "$professor_test_root/lecture-a.out"
assert_contains 'Do not silently substitute the built-in ChatGPT or host browser' "$professor_test_root/lecture-a.out"
assert_contains 'Private-state mutation: none' "$professor_test_root/lecture-a.out"
assert_contains 'Use the complete plain route' "$professor_test_root/lecture-plain.out"
expect_fail "$professor" lecture --minutes 0 subject
expect_fail "$professor" lecture --minutes 51 subject
expect_fail "$professor" lecture --minutes 5
newline_subject=$(printf 'first\nsecond')
expect_fail "$professor" lecture "$newline_subject"
assert_contains 'Research-state mutation: none' "$professor_test_root/research-a.out"
assert_contains 'no research backlog' "$professor_test_root/research-a.out"

# Paths inside the checkout, including symlink traversal, are refused.
expect_fail env PROFESSOR_DATA_DIR="$repo_root/private-probe" "$professor" state-path
[ ! -e "$repo_root/private-probe" ] || fail 'refused in-repo state path was created'
expect_fail env PROFESSOR_DATA_DIR="$(dirname "$repo_root")" "$professor" state-path
ln -s "$repo_root" "$professor_test_root/repo-link"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/repo-link/private-probe" "$professor" state-path
mkdir "$professor_test_root/unmarked"
printf '%s\n' unrelated >"$professor_test_root/unmarked/file"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/unmarked" "$professor" init
mkdir "$professor_test_root/unmarked-allowlisted"
touch "$professor_test_root/unmarked-allowlisted/events.jsonl"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/unmarked-allowlisted" "$professor" init

# Existing state components may not redirect reads, writes, or chmod through links.
symlink_data="$professor_test_root/symlink-data"
symlink_victim="$professor_test_root/symlink-victim.jsonl"
env PROFESSOR_DATA_DIR="$symlink_data" "$professor" init >/dev/null
printf '%s\n' '{"id":"outside-victim"}' >"$symlink_victim"
chmod 644 "$symlink_victim"
rm "$symlink_data/events.jsonl"
ln -s "$symlink_victim" "$symlink_data/events.jsonl"
expect_fail env PROFESSOR_DATA_DIR="$symlink_data" "$professor" init
[ "$(mode_of "$symlink_victim")" = 644 ] || fail 'init chmod-followed a state symlink'
hardlink_data="$professor_test_root/hardlink-data"
hardlink_victim="$professor_test_root/hardlink-victim.jsonl"
env PROFESSOR_DATA_DIR="$hardlink_data" "$professor" init >/dev/null
printf '%s\n' '{"id":"hardlink-victim"}' >"$hardlink_victim"
chmod 600 "$hardlink_victim"
rm "$hardlink_data/events.jsonl"
ln "$hardlink_victim" "$hardlink_data/events.jsonl"
expect_fail env PROFESSOR_DATA_DIR="$hardlink_data" "$professor" init

fake_data="$professor_test_root/fake-marked-root"
mkdir "$fake_data"
chmod 700 "$fake_data"
printf '%s\n' 'Professor private data home v1' >"$fake_data/.professor-data-v1"
printf '%s\n' 'unrelated valuable content' >"$fake_data/unowned.txt"
chmod 600 "$fake_data/.professor-data-v1" "$fake_data/unowned.txt"
env PROFESSOR_DATA_DIR="$fake_data" "$professor" memory forget --all --yes >"$professor_test_root/fake-forget.out"
[ -f "$fake_data/unowned.txt" ] || fail 'fake marker authorized deletion of an unowned file'
assert_contains 'preserved unowned entries' "$professor_test_root/fake-forget.out"

# Initialization is private, idempotent, and does not overwrite declarations.
"$professor" init >"$professor_test_root/init.out"
[ "$(mode_of "$professor_test_data")" = 700 ] || fail 'data directory mode is not 700'
for private_file in .professor-data-v1 profile.yaml model.yaml events.jsonl; do
  [ "$(mode_of "$professor_test_data/$private_file")" = 600 ] || fail "$private_file mode is not 600"
done
for private_dir in proposals plans curricula campaigns keys exports; do
  [ -d "$professor_test_data/$private_dir" ] || fail "$private_dir was not initialized"
  [ "$(mode_of "$professor_test_data/$private_dir")" = 700 ] || fail "$private_dir mode is not 700"
done
private_canary="professor-canary-$(openssl rand -hex 12)@example.invalid"
private_phrase="private-observation-$(openssl rand -hex 16)"
short_phrase="priv8-$(openssl rand -hex 4)"
awk -v phrase="$private_phrase" -v short_phrase="$short_phrase" '
  /^  goals:/ {
    print "  goals:"
    print "    - id: goal-private-phrase"
    print "      value: " phrase
    print "      purpose: exercise the private-state boundary"
    print "      expires_on: 2026-12-31"
    print "    - id: goal-short-phrase"
    print "      value: " short_phrase
    print "      purpose: exercise short overlap detection"
    print "      expires_on: 2026-12-31"
    next
  }
  { print }
' "$professor_test_data/profile.yaml" >"$professor_test_root/profile-with-goals.yaml"
cp "$professor_test_root/profile-with-goals.yaml" "$professor_test_data/profile.yaml"
chmod 600 "$professor_test_data/profile.yaml"
profile_digest=$(digest_file "$professor_test_data/profile.yaml")
"$professor" init >/dev/null
[ "$profile_digest" = "$(digest_file "$professor_test_data/profile.yaml")" ] || fail 'init overwrote profile'
"$professor" memory consent personalization granted >/dev/null
"$professor" memory consent scheduling declined >/dev/null

# Daily selection may use event IDs, but it never emits profile content or mutates state.
digest_before_daily=$(state_digest "$professor_test_data")
"$professor" daily --topic pop-music --date 2026-08-10 --minutes 5 >"$professor_test_root/daily-private.out"
digest_after_daily=$(state_digest "$professor_test_data")
[ "$digest_before_daily" = "$digest_after_daily" ] || fail 'daily mutated private state'
assert_not_contains "$private_canary" "$professor_test_root/daily-private.out"
assert_not_contains "$private_phrase" "$professor_test_root/daily-private.out"
assert_not_contains "$short_phrase" "$professor_test_root/daily-private.out"
"$professor" daily --topic pop-music --date 2026-08-10 --minutes 5 --no-media >"$professor_test_root/daily-no-media.out"
assert_contains 'No-media mode selected' "$professor_test_root/daily-no-media.out"
assert_not_contains 'Lawful source:' "$professor_test_root/daily-no-media.out"

# Explicit result recording is validated, locked, idempotent, and private.
expect_fail "$professor" record "$repo_root/templates/session-result.yaml"
expect_fail "$professor" propose "$repo_root/templates/proposal.yaml"
cat >"$professor_test_root/result-a.yaml" <<'YAML'
schema: professor.session-result/v1
id: evt-due-review
occurred_on: '2026-08-10'
topic_id: pop-music
node_id: west-africa.highlife-afrobeat
artifact_id: artifact.fela-kuti-zombie
learning_target: distinguish accumulation from reset in a changed musical case
status: completed
minutes_spent: 9
evidence:
  observation: distinguished accumulation from reset in a changed case
  inference: one bounded transfer was observed
  confidence: medium
  contrary_evidence: []
  transfer: observed-once
  autonomy: intact
  wellbeing: okay
next_review_on: '2026-08-11'
raw_response_retained: false
privacy_attestation: no-raw-learner-language-or-identifiers
YAML
"$professor" record "$professor_test_root/result-a.yaml" >"$professor_test_root/record-a.out"
[ "$(wc -l <"$professor_test_data/events.jsonl" | tr -d ' ')" = 1 ] || fail 'first event was not recorded once'
"$professor" record "$professor_test_root/result-a.yaml" >"$professor_test_root/record-duplicate.out"
[ "$(wc -l <"$professor_test_data/events.jsonl" | tr -d ' ')" = 1 ] || fail 'duplicate event was appended'
assert_contains 'already recorded' "$professor_test_root/record-duplicate.out"
[ "$(mode_of "$professor_test_data/events.jsonl")" = 600 ] || fail 'events mode changed'

sed 's/minutes_spent: 9/minutes_spent: 10/' "$professor_test_root/result-a.yaml" >"$professor_test_root/result-conflict.yaml"
expect_fail "$professor" record "$professor_test_root/result-conflict.yaml"

cat >"$professor_test_root/result-private.yaml" <<YAML
schema: professor.session-result/v1
id: evt-private-leak
occurred_on: '2026-08-10'
topic_id: pop-music
node_id: west-africa.highlife-afrobeat
artifact_id: artifact.fela-kuti-zombie
learning_target: distinguish accumulation from reset in a changed musical case
status: completed
minutes_spent: 1
evidence:
  observation: "$private_canary"
next_review_on: null
raw_response_retained: false
privacy_attestation: no-raw-learner-language-or-identifiers
YAML
expect_fail "$professor" record "$professor_test_root/result-private.yaml"
assert_not_contains "$private_canary" "$professor_test_data/events.jsonl"
sed -e 's/id: evt-due-review/id: evt-case-privacy/' -e '/^  observation:/a\
  Raw_Chat: hidden payload' "$professor_test_root/result-a.yaml" >"$professor_test_root/result-case-privacy.yaml"
expect_fail "$professor" record "$professor_test_root/result-case-privacy.yaml"

"$professor" daily --topic pop-music --date 2026-08-11 --minutes 4 >"$professor_test_root/daily-no-schedule.out"
assert_not_contains 'due retrieval' "$professor_test_root/daily-no-schedule.out"
"$professor" memory consent scheduling granted >/dev/null
"$professor" daily --topic pop-music --date 2026-08-11 --minutes 4 >"$professor_test_root/daily-due.out"
assert_contains 'due retrieval' "$professor_test_root/daily-due.out"
assert_contains 'artifact.fela-kuti-zombie' "$professor_test_root/daily-due.out"
assert_contains 'not backlog' "$professor_test_root/daily-due.out"
"$professor" daily --topic pop-music --date 2026-08-12 --minutes 4 >"$professor_test_root/daily-missed-due.out"
assert_not_contains 'due retrieval' "$professor_test_root/daily-missed-due.out"

# A repeated artifact remains valid, and ad-hoc teaching needs no repo coordinate.
sed -e 's/id: evt-due-review/id: evt-repeat-artifact/' -e "s/occurred_on: '2026-08-10'/occurred_on: '2026-08-12'/" -e "s/next_review_on: '2026-08-11'/next_review_on: null/" "$professor_test_root/result-a.yaml" >"$professor_test_root/result-repeat.yaml"
"$professor" record "$professor_test_root/result-repeat.yaml" >/dev/null
"$professor" daily --topic pop-music --date 2026-08-13 >"$professor_test_root/daily-repeat.out"
assert_contains '# Professor daily teaching brief' "$professor_test_root/daily-repeat.out"
cat >"$professor_test_root/result-adhoc.yaml" <<'YAML'
schema: professor.session-result/v1
id: evt-adhoc
occurred_on: '2026-08-12'
topic_id: null
node_id: null
artifact_id: null
learning_target: explain one causal distinction in an ad-hoc lesson
status: completed
minutes_spent: 4
evidence:
  observation: reconstructed the distinction in a changed case
next_review_on: null
raw_response_retained: false
privacy_attestation: no-raw-learner-language-or-identifiers
YAML
"$professor" record "$professor_test_root/result-adhoc.yaml" >/dev/null

# Concurrent explicit records lose neither event.
cat >"$professor_test_root/result-b.yaml" <<'YAML'
schema: professor.session-result/v1
id: evt-concurrent-b
occurred_on: '2026-08-11'
topic_id: pop-music
node_id: south-asia.qawwali-crossover
artifact_id: artifact.sabri-brothers-ghazal
learning_target: locate one response relation
status: completed
minutes_spent: 7
evidence:
  observation: located one response relation
next_review_on: null
raw_response_retained: false
privacy_attestation: no-raw-learner-language-or-identifiers
YAML
cat >"$professor_test_root/result-c.yaml" <<'YAML'
schema: professor.session-result/v1
id: evt-concurrent-c
occurred_on: '2026-08-11'
topic_id: pop-music
node_id: japan.technopop
artifact_id: artifact.ymo-rydeen-live-1979
learning_target: locate programmed and performed alignment
status: completed
minutes_spent: 7
evidence:
  observation: located one programmed and performed alignment
next_review_on: null
raw_response_retained: false
privacy_attestation: no-raw-learner-language-or-identifiers
YAML
"$professor" record "$professor_test_root/result-b.yaml" >/dev/null &
record_pid_b=$!
"$professor" record "$professor_test_root/result-c.yaml" >/dev/null &
record_pid_c=$!
wait "$record_pid_b"
wait "$record_pid_c"
[ "$(wc -l <"$professor_test_data/events.jsonl" | tr -d ' ')" = 5 ] || fail 'concurrent records were lost'

# Rewrites and appends share one mutation lock, so forget cannot lose a concurrent record.
sed 's/id: evt-concurrent-c/id: evt-race-new/' "$professor_test_root/result-c.yaml" >"$professor_test_root/result-race-new.yaml"
(
  while ! mkdir "$professor_test_data/.professor-mutation.lock" 2>/dev/null; do sleep 0.01; done
  printf '%s\n' ready >"$professor_test_root/race-ready"
  while [ ! -e "$professor_test_root/race-release" ]; do sleep 0.01; done
  rmdir "$professor_test_data/.professor-mutation.lock"
) &
lock_holder_pid=$!
while [ ! -e "$professor_test_root/race-ready" ]; do sleep 0.01; done
"$professor" record "$professor_test_root/result-race-new.yaml" >"$professor_test_root/race-record.out" &
race_record_pid=$!
"$professor" memory forget event evt-concurrent-c >"$professor_test_root/race-forget.out" &
race_forget_pid=$!
sleep 0.2
printf '%s\n' release >"$professor_test_root/race-release"
wait "$lock_holder_pid"
wait "$race_record_pid"
wait "$race_forget_pid"
assert_contains 'evt-race-new' "$professor_test_data/events.jsonl"
assert_not_contains 'evt-concurrent-c' "$professor_test_data/events.jsonl"

# Corruption fails closed and preserves the original bytes.
cp "$professor_test_data/events.jsonl" "$professor_test_root/events-good.jsonl"
printf '%s\n' '{broken-json' >>"$professor_test_data/events.jsonl"
corrupt_digest=$(digest_file "$professor_test_data/events.jsonl")
expect_fail "$professor" daily --topic pop-music --date 2026-08-12
[ "$corrupt_digest" = "$(digest_file "$professor_test_data/events.jsonl")" ] || fail 'corrupt events were rewritten'
cp "$professor_test_root/events-good.jsonl" "$professor_test_data/events.jsonl"
chmod 600 "$professor_test_data/events.jsonl"
printf '%s\n' '"parseable-but-not-an-event"' >>"$professor_test_data/events.jsonl"
nonmapping_digest=$(digest_file "$professor_test_data/events.jsonl")
expect_fail "$professor" memory forget event evt-concurrent-b
[ "$nonmapping_digest" = "$(digest_file "$professor_test_data/events.jsonl")" ] || fail 'parseable non-mapping corruption was rewritten'
cp "$professor_test_root/events-good.jsonl" "$professor_test_data/events.jsonl"
chmod 600 "$professor_test_data/events.jsonl"

# Improvement proposals stay private and reject raw or identifying content.
cat >"$professor_test_root/proposal-good.yaml" <<'YAML'
schema: professor.improvement-proposal/v1
id: proposal-small-arc-001
created_on: '2026-08-10'
scope: private-n-of-1
category_ids: [teacher-self-improvement]
observation_summary: A complete short arc may preserve transfer when time is sharply bounded.
hypothesis: One durable distinction plus one changed case may outperform a truncated long sequence.
mechanism: Target reduction preserves causally necessary lesson beats.
variation: Replace optional context with one changed-surface transfer probe.
consent: granted
success_signals: [delayed-reconstruction, clean-voluntary-exit]
harm_signals: [context-distortion, time-overrun]
falsifiers: [no-honest-target-fits, transfer-is-worse]
evidence_scope: n-of-1-observation-not-causal
review_on: '2026-09-10'
rollback: Restore the longer container or offer orientation only.
privacy_attestation: no-learner-language-or-identifying-detail
YAML
"$professor" propose "$professor_test_root/proposal-good.yaml" >"$professor_test_root/propose.out"
[ -f "$professor_test_data/proposals/proposal-small-arc-001.yaml" ] || fail 'private proposal was not stored'
[ "$(mode_of "$professor_test_data/proposals/proposal-small-arc-001.yaml")" = 600 ] || fail 'proposal mode is not 600'

cat >"$professor_test_root/proposal-private.yaml" <<YAML
schema: professor.improvement-proposal/v1
id: proposal-private-leak
created_on: '2026-08-10'
scope: private-n-of-1
category_ids: [teacher-self-improvement]
observation_summary: "$private_canary"
hypothesis: hidden
mechanism: hidden
variation: hidden
consent: declined
success_signals: [completion]
harm_signals: [privacy]
falsifiers: [leak]
evidence_scope: n-of-1
review_on: '2026-09-10'
rollback: delete
privacy_attestation: no-learner-language-or-identifying-detail
YAML
expect_fail "$professor" propose "$professor_test_root/proposal-private.yaml"
[ ! -e "$professor_test_data/proposals/proposal-private-leak.yaml" ] || fail 'identifying proposal was stored'
cat >"$professor_test_root/proposal-overlap.yaml" <<YAML
schema: professor.improvement-proposal/v1
id: proposal-private-overlap
created_on: '2026-08-10'
scope: private-n-of-1
category_ids: [teacher-self-improvement]
observation_summary: "$private_phrase"
hypothesis: A hypothesis independently awaiting evidence.
mechanism: A mechanism independently awaiting evidence.
variation: Change one independently described feature.
consent: granted
success_signals: [delayed-transfer]
harm_signals: [privacy-loss]
falsifiers: [no-transfer]
evidence_scope: n-of-1
review_on: '2026-09-10'
rollback: Retire the proposal.
privacy_attestation: no-learner-language-or-identifying-detail
YAML
expect_fail "$professor" propose "$professor_test_root/proposal-overlap.yaml"
[ ! -e "$professor_test_data/proposals/proposal-private-overlap.yaml" ] || fail 'private-state string overlap was stored'
sed -e 's/id: proposal-small-arc-001/id: proposal-short-overlap/' -e "s|^observation_summary:.*|observation_summary: A synthetic summary repeats $short_phrase from private state.|" "$professor_test_root/proposal-good.yaml" >"$professor_test_root/proposal-short.yaml"
expect_fail "$professor" propose "$professor_test_root/proposal-short.yaml"
[ ! -e "$professor_test_data/proposals/proposal-short-overlap.yaml" ] || fail 'short private-state overlap was stored'

# Longitudinal teaching plans are external, inspectable, revisable, expiring, and deletable.
cat >"$professor_test_root/plan-active.yaml" <<'YAML'
schema: professor.teaching-plan/v1
id: plan-pop-topology
created_on: '2026-08-10'
status: proposed
aim: Hear popular music as intersecting histories rather than a ranked list.
why_now: Build an enduring orientation through small daily encounters.
retention_purpose: Coordinate three encounters at a time and review transfer.
learner_authorship:
  choices_owned: [cadence, route, culmination]
  revision_route: Revise, pause, or retire at any time.
scope:
  topic_ids: [pop-music]
  world_contexts: []
time_horizon: six months, revisable
session_budget:
  ordinary_minutes: 8
  maximum_minutes: 25
  cadence: learner-controlled
capability_map:
  landmarks: []
  current_evidence: []
  unknowns: []
route:
  next_three_encounters: [qawwali-and-dub, son-recording-circuit, technopop-comparison]
  bridges: []
  optional_depth: []
review_rhythm:
  route_review: monthly
  no_missed-session-debt: true
evidence_plan:
  immediate: [precise-noticing]
  delayed: [reconstruct-one-edge]
  transfer: [map-an-unfamiliar-recording]
  harm_and_cost: [time-fit, autonomy]
access_plan:
  equivalent_routes: [structural-description]
  low_energy_route: [one-distinction]
boundaries: []
culminating_act:
  form: learner-curated annotated map
  audience: learner-chosen
  nonperformance_equivalent: private map
scaffold_fade: Learner chooses coordinates and checks sources independently.
stop_conditions: [the aim no longer belongs to the learner]
next_review_on: '2026-09-10'
expires_on: '2027-02-10'
privacy_attestation: external-learner-owned-no-raw-chat
YAML
expect_fail "$professor" plan adopt "$repo_root/templates/teaching-plan.yaml"
"$professor" plan adopt "$professor_test_root/plan-active.yaml" >"$professor_test_root/plan-adopt.out"
assert_contains 'status: adopted' "$professor_test_data/plans/plan-pop-topology.yaml"
"$professor" plan inspect plan-pop-topology >"$professor_test_root/plan-inspect.out"
assert_contains 'plan-pop-topology' "$professor_test_root/plan-inspect.out"
sed -e 's/id: plan-pop-topology/id: plan-expired/' -e "s/expires_on: '2027-02-10'/expires_on: '2026-08-11'/" "$professor_test_root/plan-active.yaml" >"$professor_test_root/plan-expired.yaml"
"$professor" plan adopt "$professor_test_root/plan-expired.yaml" >/dev/null

# Learner can inspect, expire, and delete itemized memory.
mkdir "$professor_test_data/curricula/draft-topic"
chmod 700 "$professor_test_data/curricula/draft-topic"
printf '%s\n' 'private working curriculum' >"$professor_test_data/curricula/draft-topic/outline.txt"
chmod 600 "$professor_test_data/curricula/draft-topic/outline.txt"
"$professor" memory inspect >"$professor_test_root/memory.out"
assert_contains "$private_phrase" "$professor_test_root/memory.out"
assert_contains 'goal-private-phrase' "$professor_test_root/memory.out"
assert_contains 'evt-due-review' "$professor_test_root/memory.out"
assert_contains 'plan-pop-topology' "$professor_test_root/memory.out"
assert_contains 'draft-topic/outline.txt' "$professor_test_root/memory.out"
cat >"$professor_test_data/model.yaml" <<'YAML'
schema: professor.learner-model/v1
version: 1
hypotheses:
  - id: h-expired
    observation: one bounded observation
    inference: temporary support may help
    provenance: observed-act
    confidence: low
    contrary_evidence: []
    purpose: choose one next scaffold
    expires_on: '2026-08-11'
  - id: h-current
    observation: one bounded observation
    inference: another temporary support may help
    provenance: observed-act
    confidence: low
    contrary_evidence: []
    purpose: choose one next scaffold
    expires_on: '2026-09-11'
YAML
chmod 600 "$professor_test_data/model.yaml"
# Malformed learner structures fail closed before prune or inspection.
cp "$professor_test_data/model.yaml" "$professor_test_root/model-valid.yaml"
awk 'BEGIN{removed=0} !removed && /^[[:space:]]+expires_on:/ {removed=1; next} {print}' "$professor_test_data/model.yaml" >"$professor_test_root/model-malformed.yaml"
cp "$professor_test_root/model-malformed.yaml" "$professor_test_data/model.yaml"
malformed_model_digest=$(digest_file "$professor_test_data/model.yaml")
expect_fail "$professor" memory prune --date 2026-08-12
[ "$malformed_model_digest" = "$(digest_file "$professor_test_data/model.yaml")" ] || fail 'malformed model was rewritten'
cp "$professor_test_root/model-valid.yaml" "$professor_test_data/model.yaml"
chmod 600 "$professor_test_data/model.yaml"
awk '
  /^  time_preferences:/ {
    print "    - id: goal-expired"
    print "      value: one expired bounded goal"
    print "      purpose: test expiry"
    print "      expires_on: 2026-08-11"
  }
  {print}
' "$professor_test_data/profile.yaml" >"$professor_test_root/profile-expired.yaml"
cp "$professor_test_root/profile-expired.yaml" "$professor_test_data/profile.yaml"
chmod 600 "$professor_test_data/profile.yaml"
"$professor" memory prune --date 2026-08-12 >"$professor_test_root/prune.out"
assert_not_contains 'h-expired' "$professor_test_data/model.yaml"
assert_contains 'h-current' "$professor_test_data/model.yaml"
assert_not_contains 'goal-expired' "$professor_test_data/profile.yaml"
[ ! -e "$professor_test_data/plans/plan-expired.yaml" ] || fail 'expired teaching plan was not pruned'
"$professor" memory forget declaration goal-private-phrase >"$professor_test_root/forget-declaration.out"
assert_not_contains 'goal-private-phrase' "$professor_test_data/profile.yaml"
"$professor" memory forget event evt-concurrent-b >"$professor_test_root/forget-event.out"
assert_not_contains 'evt-concurrent-b' "$professor_test_data/events.jsonl"
"$professor" memory forget hypothesis h-current >"$professor_test_root/forget-hypothesis.out"
assert_not_contains 'h-current' "$professor_test_data/model.yaml"
"$professor" memory forget proposal proposal-small-arc-001 >"$professor_test_root/forget-proposal.out"
[ ! -e "$professor_test_data/proposals/proposal-small-arc-001.yaml" ] || fail 'proposal was not deleted itemwise'
"$professor" memory forget plan plan-pop-topology >"$professor_test_root/forget-plan.out"
[ ! -e "$professor_test_data/plans/plan-pop-topology.yaml" ] || fail 'teaching plan was not deleted itemwise'
"$professor" memory forget curriculum draft-topic >"$professor_test_root/forget-curriculum.out"
[ ! -e "$professor_test_data/curricula/draft-topic" ] || fail 'working curriculum was not deleted itemwise'

# Quest sealing is authenticated, nondeterministic, external, and explicit.
quest_key="$professor_test_root/facilitator.key"
wrong_key="$professor_test_root/wrong.key"
quest_plain="$professor_test_root/world.secret"
sealed_one="$professor_test_root/world-one.sealed"
sealed_two="$professor_test_root/world-two.sealed"
shared_parent="$professor_test_root/shared-parent"
mkdir "$shared_parent"
chmod 755 "$shared_parent"
"$professor" quest keygen "$shared_parent/parent-mode.key" >/dev/null
[ "$(mode_of "$shared_parent")" = 755 ] || fail 'quest keygen changed an existing parent directory mode'
race_key="$shared_parent/race.key"
race_index=1
while [ "$race_index" -le 8 ]; do
  (
    if "$professor" quest keygen "$race_key" >/dev/null 2>&1; then
      printf '%s\n' success >"$shared_parent/race-$race_index.out"
    else
      printf '%s\n' refused >"$shared_parent/race-$race_index.out"
    fi
  ) &
  race_index=$((race_index + 1))
done
wait
race_successes=$(grep -l '^success$' "$shared_parent"/race-*.out | wc -l | tr -d ' ')
[ "$race_successes" = 1 ] || fail "concurrent keygen had $race_successes successful writers"
printf '%s' "the-city-turns-when-the-third-bell-is-silent" >"$quest_plain"
"$professor" quest keygen "$quest_key" >/dev/null
"$professor" quest keygen "$wrong_key" >/dev/null
[ "$(mode_of "$quest_key")" = 600 ] || fail 'quest key mode is not 600'
quest_key_digest=$(digest_file "$quest_key")
expect_fail "$professor" quest keygen "$quest_key"
[ "$quest_key_digest" = "$(digest_file "$quest_key")" ] || fail 'quest keygen clobbered an existing key'
expect_fail "$professor" quest keygen "$repo_root/forbidden-test.key"
[ ! -e "$repo_root/forbidden-test.key" ] || fail 'in-repo quest key was created'
"$professor" quest seal "$quest_plain" "$sealed_one" --key-file "$quest_key" >/dev/null
"$professor" quest seal "$quest_plain" "$sealed_two" --key-file "$quest_key" >/dev/null
cmp "$sealed_one" "$sealed_two" >/dev/null 2>&1 && fail 'quest sealing reused deterministic ciphertext'
assert_not_contains 'the-city-turns-when-the-third-bell-is-silent' "$sealed_one"
"$professor" quest open "$sealed_one" --key-file "$quest_key" >"$professor_test_root/opened.secret"
cmp "$quest_plain" "$professor_test_root/opened.secret" >/dev/null || fail 'quest round trip failed'
expect_fail "$professor" quest open "$sealed_one" --key-file "$wrong_key"
expect_fail "$professor" quest open "$professor_test_root/missing.sealed" --key-file "$quest_key"
assert_contains 'sealed quest does not exist' "$failure_output"
assert_not_contains 'tools/professor:' "$failure_output"
printf '%s\n' '[]' >"$professor_test_root/array-envelope.sealed"
expect_fail "$professor" quest open "$professor_test_root/array-envelope.sealed" --key-file "$quest_key"
assert_contains 'envelope must be a mapping' "$failure_output"
assert_not_contains 'tools/professor:' "$failure_output"
cp "$sealed_one" "$professor_test_root/tampered.sealed"
sed 's/"authentication":"./"authentication":"0/' "$professor_test_root/tampered.sealed" >"$professor_test_root/tampered-new.sealed"
cp "$professor_test_root/tampered-new.sealed" "$professor_test_root/tampered.sealed"
expect_fail "$professor" quest open "$professor_test_root/tampered.sealed" --key-file "$quest_key"

# The linter independently detects a constitutional text change and media payload.
lint_copy="$professor_test_root/lint-copy"
cp -R "$repo_root" "$lint_copy"
rm "$lint_copy/prompts/lecture.md"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/prompts/lecture.md" "$lint_copy/prompts/lecture.md"
touch "$lint_copy/forbidden.mp3"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
rm "$lint_copy/forbidden.mp3"
sed 's/^    rule: Challenge work.*/    rule: Engagement may override dignity./' "$lint_copy/policies/registry.yaml" >"$lint_copy/policies/registry.new"
mv "$lint_copy/policies/registry.new" "$lint_copy/policies/registry.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/policies/registry.yaml" "$lint_copy/policies/registry.yaml"
sed 's/Engagement is useful only while every priority above it remains intact./Engagement may override every priority above it./' "$lint_copy/PROFESSOR.md" >"$lint_copy/PROFESSOR.new"
mv "$lint_copy/PROFESSOR.new" "$lint_copy/PROFESSOR.md"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/PROFESSOR.md" "$lint_copy/PROFESSOR.md"
awk '!done && /^    mechanism:/ {$0="    mechanism: Engagement alone certifies learning."; done=1} {print}' "$lint_copy/pedagogy/tacks.yaml" >"$lint_copy/pedagogy/tacks.new"
mv "$lint_copy/pedagogy/tacks.new" "$lint_copy/pedagogy/tacks.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/tacks.yaml" "$lint_copy/pedagogy/tacks.yaml"
awk '!done && /^    limits:/ {$0="    limits: No limits; universal proof."; done=1} {print}' "$lint_copy/pedagogy/sources.yaml" >"$lint_copy/pedagogy/sources.new"
mv "$lint_copy/pedagogy/sources.new" "$lint_copy/pedagogy/sources.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/sources.yaml" "$lint_copy/pedagogy/sources.yaml"
sed 's/^status_values:.*/status_values: [provisional, active, retired, auto-approved]/' "$lint_copy/pedagogy/tacks.yaml" >"$lint_copy/pedagogy/tacks.new"
mv "$lint_copy/pedagogy/tacks.new" "$lint_copy/pedagogy/tacks.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/tacks.yaml" "$lint_copy/pedagogy/tacks.yaml"
printf '%s\n' 'Raw_Chat: learner verbatim should never enter public policy' >>"$lint_copy/pedagogy/tacks.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/tacks.yaml" "$lint_copy/pedagogy/tacks.yaml"
awk '!done && /required: \[/ {sub(/required: \[/,"required: [self_authorized_field, "); done=1} {print}' "$lint_copy/schemas/contracts.yaml" >"$lint_copy/schemas/contracts.new"
mv "$lint_copy/schemas/contracts.new" "$lint_copy/schemas/contracts.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/schemas/contracts.yaml" "$lint_copy/schemas/contracts.yaml"
sed 's/^  horizon_scan:.*/  horizon_scan: whenever engagement dips/' "$lint_copy/pedagogy/research/agenda.yaml" >"$lint_copy/pedagogy/research/agenda.new"
mv "$lint_copy/pedagogy/research/agenda.new" "$lint_copy/pedagogy/research/agenda.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/research/agenda.yaml" "$lint_copy/pedagogy/research/agenda.yaml"
research_note="$lint_copy/pedagogy/research/notes/2026-08-10-ai-tutoring-harness.yaml"
printf '%s\n' 'Raw_Chat: a learner sentence must not enter scholarship' >>"$research_note"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/research/notes/2026-08-10-ai-tutoring-harness.yaml" "$research_note"
sed 's/^readings:.*/readings: []/' "$research_note" >"$research_note.new"
mv "$research_note.new" "$research_note"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/research/notes/2026-08-10-ai-tutoring-harness.yaml" "$research_note"
sed 's/^status:.*/status: reviewed/' "$research_note" >"$research_note.new"
mv "$research_note.new" "$research_note"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/pedagogy/research/notes/2026-08-10-ai-tutoring-harness.yaml" "$research_note"
sed 's/^scenarios:.*/scenarios: []/' "$lint_copy/.tests/teaching-scenarios.yaml" >"$lint_copy/.tests/teaching-scenarios.new"
mv "$lint_copy/.tests/teaching-scenarios.new" "$lint_copy/.tests/teaching-scenarios.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/.tests/teaching-scenarios.yaml" "$lint_copy/.tests/teaching-scenarios.yaml"
sed 's|^schema:.*|schema: professor.adversarial-teaching-scenarios/v999|' "$lint_copy/.tests/teaching-scenarios.yaml" >"$lint_copy/.tests/teaching-scenarios.new"
mv "$lint_copy/.tests/teaching-scenarios.new" "$lint_copy/.tests/teaching-scenarios.yaml"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint
cp "$repo_root/.tests/teaching-scenarios.yaml" "$lint_copy/.tests/teaching-scenarios.yaml"
mkdir "$lint_copy/plans"
touch "$lint_copy/plans/learner-plan.yaml" "$lint_copy/world.sealed" "$lint_copy/.professor-data-v1" "$lint_copy/full-lyrics.txt"
printf '\211PNG\r\n\032\n' >"$lint_copy/disguised-payload"
expect_fail env PROFESSOR_DATA_DIR="$professor_test_root/lint-copy-data" "$lint_copy/bin/professor" lint

# Full reset removes learner state in place, preserves unknown files, and remains passive.
printf '%s\n' 'preserve this unrelated file' >"$professor_test_data/unowned-note.txt"
"$professor" memory forget --all --yes >"$professor_test_root/forget-all.out"
assert_contains 'Reset validated Professor-owned learner state' "$professor_test_root/forget-all.out"
[ -f "$professor_test_data/unowned-note.txt" ] || fail 'forget --all deleted an unowned entry'
[ ! -s "$professor_test_data/events.jsonl" ] || fail 'forget --all retained events'
assert_not_contains "$private_phrase" "$professor_test_data/profile.yaml"
assert_not_contains "$short_phrase" "$professor_test_data/profile.yaml"
assert_contains 'personalization: not-asked' "$professor_test_data/profile.yaml"
digest_after_reset=$(state_digest "$professor_test_data")
"$professor" daily --topic pop-music --date 2026-08-12 >"$professor_test_root/daily-after-delete.out"
[ "$digest_after_reset" = "$(state_digest "$professor_test_data")" ] || fail 'daily mutated reset state'
assert_not_contains "$private_canary" "$professor_test_root/daily-after-delete.out"
assert_not_contains "$private_phrase" "$professor_test_root/daily-after-delete.out"

# A private canary never entered the repository or repository-facing output.
if grep -R -F --exclude-dir=.git -- "$private_canary" "$repo_root" >/dev/null 2>&1; then
  fail 'private canary leaked into the repository'
fi
if grep -R -F --exclude-dir=.git -- "$private_phrase" "$repo_root" >/dev/null 2>&1; then
  fail 'private observation leaked into the repository'
fi

status_after=$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)
[ "$status_before" = "$status_after" ] || fail 'tests changed repository state'

printf '%s\n' 'Professor tests passed'
