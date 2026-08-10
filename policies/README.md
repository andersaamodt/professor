# Policy release guard

`registry.yaml` owns stable policy propositions and precedence.
`PROFESSOR.md` owns their enacted interpretation. The constitutional floor is
therefore the combination of:

- every registry record named by the runtime's fixed constitutional ID set,
  sorted by ID; and
- the complete, line-ending-normalized `PROFESSOR.md` execution contract; and
- the complete, line-ending-normalized adversarial teaching contract in
  `.tests/teaching-scenarios.yaml`.

`constitutional.sha256` pins the SHA-256 of the sorted core registry records
and both complete, line-ending-normalized contracts. Lint must fail when any
of these authorities changes while the pin does not.
Updating the pin is not a routine formatting operation: it accompanies explicit
human review, a decision record, adversarial tests, and a versioned release. A
matching digest is evidence that review was made visible; it is not evidence
that a policy is good.

The runtime deliberately hard-codes the constitutional IDs and required schema
fields. A mutable catalog cannot redefine the validator that constrains it.
