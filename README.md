# meowdlm - deductive learning experiment (Maru / LLVM IR native inference)

Version 0.0062. Same conversation task as the original MeowLLM (3,447,552 parameters, gradient
training), solved without gradients. Judgement, derivation, generation and persistence run in Maru
(an LLVM IR Lisp); Python remains only for web fetching and data conversion.

```text
src/meow/*.l        Maru-native model
                      syntax.l    Earley derivation over a category lattice
                      parse.l     derivation trees (span split) + linearisation
                      lexfeat.l  six-tuple feature lexicon and agreement check
                      featgate.l structural derivation AND feature check as one verdict
                      lexfix.l   derivation-preserving lexicon pruning
                      induce.l   rule candidate admission / invention experiments
                      evidence.l cue-mass judgement with IDF and margin (Q16)
                      horn.l     Horn closure, closed-world answers
                      certify.l  derivation certificates + independent checker
                      exp.l      experience records (L/R/C)
                      learn.l    learners that record their own experience
                      apply.l    experience -> rules/lexicon loader
                      surface.l  frame/slot realisation
data/*.l            static data (some files are sources - see data/README.md)
tools/              data converters + S-expression sorter (sx.py)
tools/fetch/        web collection (the Python-permitted area) -> cache/ (git-ignored)
experiments/parity  drivers and Python-reference differentials
tests/              Maru self-tests
docs/               release records, including negative results and retractions
state/              runtime generations (git-ignored)
```

## Running

```bash
cd meowdlm_v0.0062
MARU=/research/dlm_v0.0284/maru-compiler ./verify.sh   # 30 sections, 24 gates, ~20 min
```

The Maru runtime is an external binary; every model module and its gate run from this tree.

## Current performance

| axis | meowdlm 0.0062 | original MeowLLM (step 2000) |
|---|---|---|
| category judgement, in-domain 150 (P25 gate) | **103/150 = 0.687** | 70/150 = 0.467 |
| judgement, gate 0 (reference row) | 105/150 = 0.700 | - |
| out-of-domain abstention, 20 | **16/20** | 0/20 |
| new OOD fixture, 20 | **20/20** | - |
| corpus derivation, 1,000 sentences | **340** (33 -> 36 axioms) | no checker |
| held-out 700 sentences | 186 -> **228** (+22.6%) | - |
| generation passing own grammar, 15 categories | **4/15** | no checker |
| feature/agreement witnesses, 9 cases | **9/9** (3 -> 6 -> 9) | - |
| lexicon ambiguity, total categories | 599 -> **580** | - |
| parameters / gradient steps | **0 / 0** | 3,447,552 / 2000 |
| character fluency (generation) | 0.982 | **0.996** |
| discourse coherence | 0.387 | - |
| evidence / certificates / experience | proof chains, counterexample paths, 4+ records | none |

## Established (measured)

- **Judgement**: cue-mass classifier with IDF weighting, Q16 integer arithmetic, 0.687 in-domain
  with the 0.25 cue-hit gate, 16/20 OOD abstention and 20/20 on a separate 20-item OOD fixture.
- **Derivation**: 340/1,000 corpus sentences with 36 axioms; 1,000-sentence parity against the
  Python reference; derivation trees with 100/100 linearisation round-trip.
- **Feature binding (0.0062)**: `fg-accept` combines structural derivation with the feature check.
  Witness agreement rises 3/9 -> 6/9 with the gate and **9/9** after four counterexample-driven
  lexicon revisions (`cat->N`, `cats->N`, `chases/chase->V`), with corpus derivation preserved at
  27/60. `me sleep` (case violation) is rejected and `the cat chases me` (accusative object) is
  accepted simultaneously.
- **Experience (0.0057/0.0062)**: learners write L/R/C records themselves, saved with FNV
  pre-check and atomic replace, reloaded by hash, and re-applied: stored experience alone
  reproduces 9/9.
- **State (0.0051)**: journal + snapshot, pre-load hash verification, gen mismatch rejection.

## Not established (honest record)

- **Rule invention**: 0.0045-0.0048 frequency/pair merging showed zero training gain; the
  substitutability definition (0.0060) localises defects to symbols but has not replaced it yet.
- **Free generation**: surface output is frame/slot assembly; 4/15 categories pass this project's
  own grammar. The generate-check loop is implemented but not yet wired into the shipping path.
- **OOV absorption**: character-similarity mapping was harmful (-3.1 to -6.2 pp, 0.0043);
  adding the 9 blocking tokens alone gave no gain (0.0059) because those sentences fail on
  structure, not vocabulary.
- **Feature unification inside parsing**: features currently gate the verdict rather than travel
  through the derivation, so tokens outside the feature lexicon fall back to structure only.
- **Corpus/task breadth**: 201 unique inputs and 554 vocabulary items. The derivation ceiling is
  668/1,000 because 332 sentences contain out-of-vocabulary tokens.

## Boundaries

- Witness labels come from `lf-check` (self-consistency), not from an external gold standard.
- The 9 witness cases and the 20-item OOD fixture are small fixtures written in this project.
- FNV-32 detects accidental corruption; adversarial tampering needs a separate manifest.
- Fluency figures use different metrics than the original model (character-level vs bigram).

## Reading order

`docs/release-0062.md` (feature binding and experience), `docs/release-0058.md` (re-comparison and
operating-point correction), `docs/release-0055.md` (trees), `docs/release-0048.md` (the retraction
of the invention numbers). Retracted figures are kept with their reasons.
