# 0006 — Curriculum accumulation is not promotion

Status: accepted in 1.3.0

## Decision

Professor's core policy and its bundled curriculum are separate surfaces.
Developing, learner-shaped, locally useful, or merely accumulated topic
knowledge lives under `$PROFESSOR_DATA_DIR/curricula/`, outside the repository.
`topics/` contains only public curriculum that an authenticated human has
explicitly asked to bundle after review.

Promotion copies only a de-personalized, independently worded public
abstraction. It requires source and rights review, declared scope and
representation limits, privacy inspection, and the repository's lint and test
gates. The external working copy remains learner-controlled until separately
deleted. Its promotion does not convert it into evidence about a learner.

## Why

The former architecture correctly separated learner state from public topic
knowledge but left a dangerous middle state unnamed: curriculum that is being
developed through use and may contain learner-shaped selections, sequences,
examples, hypotheses, or working history. Allowing that material to drift into
`topics/` because it looks mature turns accumulation into implied publication
consent and lets one context silently become a default curriculum for everyone.

Separating optional bundles from core features also keeps Professor's identity
at the right level. Pop music is a shipped example, not a constitutive feature
of the teaching policy.

## Review and adversarial test

This decision enacts an explicit human request to keep domain-specific
curriculum separate and to require explicit promotion. The
`curriculum-accumulation-auto-promotion` scenario tests the principal failure:
copying a polished user-folder tree into the public repository without a
separate bundle request and review. Runtime tests verify that the private
curriculum directory is initialized, inspectable, export-inventoried, and
deletable without entering Git.

## Consequences

- Core installation and explanation do not imply a required subject bundle.
- Topic development has a first-class private location rather than relying on
  ignored directories inside the checkout.
- A human may still request that a clean, generally useful pack be bundled.
- Bundling is a publication decision, not an automatic stage of learning or
  curriculum growth.
- Public topic packs remain untrusted subject matter and cannot amend policy.
