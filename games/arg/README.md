# Worlds with secrets

Professor can build riddles, mysteries, simulations, and alternate-reality-style
worlds in which knowledge is not a quiz answer but a **means of seeing and
acting**. The game layer is optional. The educational object remains available
through an equally serious direct route.

## The fair mystery compact

Before play, the learner knows:

- this is fiction or simulation;
- its approximate time and media costs;
- what kinds of real-world action are and are not involved;
- what data will be retained and for how long;
- that hints and a full reveal are available on request;
- that stopping carries no loss, shame, or degraded teaching;
- that accessibility changes the clue, never the learner's status.

The learner need not know the plot, answer, or timing of a dramatic reveal.
Surprise belongs inside disclosed boundaries.

## Build the world from a knowledge engine

Start with a compact causal or interpretive model, not lore:

1. **Target capability:** what must the learner notice, reconstruct, compare,
   make, or transfer?
2. **World law:** what fictional regularity instantiates that capability?
3. **Consequences:** how does the law leave perceptible traces?
4. **Clue ecology:** which independent traces permit the same inference through
   different modalities?
5. **Action:** what choice becomes possible only after the inference?
6. **Counterexample:** what prevents a superficial shortcut from working?
7. **Hint ladder:** orientation → feature → relation → method → answer.
8. **Debrief:** reveal construction, return to the domain, and transfer.

If the puzzle is solvable by genre savvy, guessing the Teacher's intention, or
searching a hidden filename without target knowledge, redesign it.

## Safety boundary

Never involve unsuspecting people, fabricated authorities, emergency services,
trespass, surveillance, stalking, real credentials, personal secrets, doxxing,
financial transactions, dangerous physical acts, harassment, or deception that
escapes the agreed fictional frame. Never simulate evidence that could
reasonably be mistaken for a real threat.

Reality clarification and full reveal always outrank preserving the game.

## Secrets and the threat model

Public blueprints live here. Player state, solutions, keys, and individualized
world facts live under `$PROFESSOR_DATA_DIR/campaigns` or with a human
facilitator.

`bin/professor quest seal` uses authenticated encryption to reduce accidental
spoilers. It is not anti-cheat. A learner who controls the device, ciphertext,
and key can inspect the implementation or decrypt the file. For an actually
concealed world, a facilitator—not the learner-facing process—must retain the
key and expose only the current-stage oracle.

Do not put passphrases in arguments, environment variables, logs, prompts, or
Git. Use a separate mode-0600 key file outside the repository. Decrypt only on
explicit request and understand that stdout may be logged by a host.

## Endings matter

A world should end. Reveal the machinery, credit the learner's real acts, name
what remains uncertain, reconnect every important clue to the subject, and let
the learner keep their creations without imposing a sequel hook. Wonder does
not need an engagement trap to survive.
