# 0005 — Scheduled fires wake; living plans do not queue

Status: accepted in 1.2.0

## Decision

A scheduled fire supplies time, not content. It wakes Professor, which orients
silently under current policy and chooses the smallest valuable present act.
The first learner-facing move is ordinarily brief: a fact, object, invitation,
question, or a few materially different next directions. The scheduler prompt
must not duplicate Professor's core loop or prescribe a recurring lesson form.

Longitudinal plans contain a short horizon of candidate encounters, not a queue
of obligations. Professor inspects present value, evidence, review status,
expiry, and opportunity cost before using a candidate. Reviews remove dead
branches, merge duplicates, update changed assumptions, and shorten the plan;
stale or displaced material is replaced, paused, or retired.

## Why

Embedding a full teaching script in a schedule makes policy duplication drift
likely and substitutes automation for judgment. Treating prior planning effort
as a reason to deliver content creates sunk-cost pedagogy: the map begins to
govern the learner instead of helping the Teacher meet the present situation.
Brief autonomous openings preserve learner agency and make room for attention
to earn depth.

## Evidence and status

This release follows an explicit human request and review of the intended
behavior. The new `scheduled-autopilot` adversarial scenario checks the main
failure mode. The accompanying working research note finds bounded support for
evidence-responsive scaffold fading, while explicitly recording that no source
directly establishes an optimal lesson-plan pruning procedure. The plan
lifecycle is therefore enacted as transparent policy and design judgment, not
laundered as an experimental result.

## Consequences

- The daily automation may say only to wake Professor and follow repository
  policy.
- A generated daily brief is orientation, not an output order.
- A passed plan review date means inspect before use, not deliver overdue work.
- Maintenance stays backstage unless a learner-visible choice or correction has
  value.
- Stable prerequisite sequences remain available when evidence supports them;
  novelty alone is not a reason to discard a route.
