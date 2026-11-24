# meowdlm - deductive learning experiment (Maru / LLVM IR native inference)

Version 0.0071. Same conversation task as the original MeowLLM (3,447,552 parameters, gradient
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
                      sem.l      458-word grammar: parse trees + meaning terms + node certificates
                      an.l       pronoun resolution with explicit abstention
                      nm.l       meaning term -> atom naming layer
                      eq.l       number-equivalence layer + KB lookup (3 arms)
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

## Why these experiments

The goal is to explore whether transformer capacity can be dismantled and rebuilt as a deductive
learner: a system where judgement, revision and derivation are explicit, checkable and cheap, so that
learning and revision cost far less power and data than GPU-clustered training. This is a research
hypothesis about energy and generalisation, and this tree keeps the evidence and the falsifiers
separate on purpose. Sibling trees are named explicitly (`ded_ladder_v0.0001/`, `dlm_v0.0284/`);
paths without a tree prefix are inside this tree.

**Measured, so far (small closed universes)**

- Local revision without regression: one counterexample is absorbed in CPU ~0.16 s (candidate sweep
  ~0.49 s, existing certificates 0/100 regressed) in `ded_ladder_v0.0001/docs/release-L2.md`, while a
  164k-parameter transformer needed 5.16 s of GPU retraining and still sat at counterexample loss
  15.18 -> 13.49. `ded_ladder_v0.0001/docs/release-L3.md` adds deductive 100% at K=25 (transformer
  median 6.5/8 at K=36) and 93 ms vs 3.74 s in the same process (40x).
- Zero-gradient judgement with abstention: 0.687 in-domain vs 0.467 for the original MeowLLM
  (3.45M parameters, 2,000 steps), out-of-domain abstention 16/20 vs 0/20 (0.0070 table below).
- Dismantling evidence: widening or deepening the capacity axes (width, depth, phase, multi-register)
  was a statistical null in `dlm_v0.0284/docs/release-0270.md`, and the gains came from symbolic
  structure: verified contracts +12..16 pp, obligation decomposition FOCUS +6.1 pp, 54% fewer search
  nodes.
- Closed loop over a real (if small) grammar: 0.0071 derives meaning terms and node certificates for
  all 286 sentences the 458-word grammar accepts, resolves pronouns with explicit abstention (96 -> 0
  pronoun constants), and answers 40 number-variant queries at 40/40 with the equivalence layer
  against 0/40 without it.

**Hypothesis, not yet judged**

That this advantage survives mid- and large-scale open language and knowledge work, and can displace
or share a large part of GPU-clustered LLM energy. Every measurement here comes from small closed
universes (554 words, 36 ground atoms, 40 pairs, 286 derived sentences). The generalisation is
untested, so this README abstains on it.

**What would falsify the programme**

1. *Energy reversal under scale.* Candidate enumeration, backtracking and whole-certificate checking
   may grow faster than matmul. Early warnings: cold-start 7.8x (target 1/10 not met,
   `ded_ladder_v0.0001/docs/release-L3.md`) and the 1.23x rule-index ceiling with per-parse allocation and
   string handling dominating (`docs/release-0069.md`).
2. *Statistical-regularity ceiling of open language.* Absorbing free paraphrase and OOV has cost
   precision and coverage sharply: suspicious terms 5.0% -> 12.4%, shuffle acceptance +45%
   (`dlm_v0.0284/docs/release-0283.md`, `docs/release-0063.md`). With no mechanism for that region,
   the applicable scope stays narrow.
3. *Limits of rebuilding inside the transformer.* Type attention (S1) and obligation readout (S2) were
   null over 15 seeds (-0.27 pp ns, `dlm_v0.0284/docs/release-0270.md`). A heterogeneous design
   (symbolic search plus a very small numeric policy or an EML-style continuous compression) may beat
   rebuilding attention blocks, and that comparison is still open.

**Measurement discipline for the next runs**

Accuracy and example counts are not enough to claim an energy win. Every subsequent gate records
energy per task (J/task for CPU and GPU arms), cumulative learning plus revision energy, and memory
allocation, and sweeps vocabulary size and inference depth to locate the knee where search cost stays
below matrix-multiply cost. Below that knee the programme is a domain tool; above it the claim becomes
testable.

## Running

```bash
cd meowdlm_v0.0070
MARU=/research/dlm_v0.0284/maru-compiler ./verify.sh   # 38 sections, 11 gate markers, ~35 min
```

The Maru runtime is an external binary; every model module and its gate run from this tree.

## Current performance

| axis | meowdlm 0.0062 | original MeowLLM (step 2000) |
|---|---|---|
| category judgement, in-domain 150 (P25 gate) | **103/150 = 0.687** | 70/150 = 0.467 |
| judgement, gate 0 (reference row) | 105/150 = 0.700 | - |
| out-of-domain abstention, 20 | **16/20** | 0/20 |
| new OOD fixture, 20 | **20/20** | - |
| corpus derivation, 1,000 sentences | **340** (33 -> 36 axioms) / **396** with OOV hypotheses (0.0063) | no checker |
| held-out 700 sentences | 186 -> **228** (+22.6%) | - |
| generation passing own grammar, 15 categories | **4/15** | no checker |
| feature/agreement witnesses, 9 cases | **9/9** (3 -> 6 -> 9) | - |
| lexicon ambiguity, total categories | 599 -> **580** | - |
| parameters / gradient steps | **0 / 0** | 3,447,552 / 2000 |
| character fluency (generation) | 0.982 | **0.996** |
| discourse coherence | 0.387 | - |
| meaning terms over the 1,000-sentence corpus | **286/286 derived, certificates 286/286** (0.0071) | no checker |
| pronoun constants in atoms | **96 -> 0** (resolved 12, abstained 84) (0.0071) | n/a |
| paraphrase queries (number variation), 40 | **on 40/40 / off 0/40 / over-merge 0 with 40 wrong** (0.0071) | n/a |
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
- **Every-node certificate re-derivation and working defaults (0.0070)**: the checker now re-derives each
 node (root and descendants) from the declaration and checks a recorded parent-to-child parameter chain;
 before this, only the root was re-derived and grandchild mutations passed. Seven layout-preserving
 mutation arms (tag, interface values, all-`none`, key deletion, semantics, deep leaf number, ungrammatical
 phrase) are all rejected 0/150 while each arm actually changes 150/150 trees, and disabling the
 interface comparator in an ablation flips the value arm to 150/150, which shows the arm tests the
 comparator rather than tree shape. `bind` now unifies instead of overwriting (both constraint orders give
 the same verdict) and an unregistered guard fails closed. `Comp` rules carry semantic slots, so copular
 complements are no longer empty: `an mine was an fish` -> `(clause (np an mine) (vp was (comp (np an
 fish))))`. The parser and generator are one worker parameterized by a rule-lookup function, so the
 indexed and scanning paths cannot drift apart.
- **Semantic slot and specialization throughput (0.0069)**: rules may carry `(sem predicate child-indices...)`, so
 a node records a composed meaning term (`an rain chases the cat` -> `(clause (np an rain) (vp chases (np the
 cat)))`) and the checker rebuilds that term from the children, rejecting forged semantics 0/150 while
 structure and linearization stay at 150/150. Throughput was measured on 1,800 parses with the same binary:
 a precomputed category-to-rules index runs 1.20-1.23x faster than rescanning the declaration each call
 (0.617 vs 0.743 ms/parse). That is a modest gain: scanning the declaration is not the dominant cost, so
 allocation per parse and character-list string handling are the next bottlenecks. LLVM IR emission is not
 part of this tree, so the comparison is specialization versus interpretation, not compiled versus
 interpreted code.
- **Gate repair, real default checking, strict certificates (0.0068)**: three defects from the review are
 fixed. `fg-ifall` is now actually called before interface values are produced, so the 0.0066 default
 comparison works: a single-difference `S` default of person 1 accepts 1 of 10 samples with zero
 third-person accepts while `i sleep` stays true. (`docs/release-0067.md` had explained the old 9/9 as a
 semantic consequence; that explanation was wrong and is corrected here.) The certificate checker now
 re-derives every node locally from the declaration (leaf lexicon entry or child interface values, then
 `fg-cons`/`fg-cmatch`/`fg-ifall`) and compares the node's recorded interface values, with the root
 required to be `S`; forged tags, forged values, a non-`S` subtree and an agreement-breaking leaf swap are
 all rejected 0/150. Rule results are interleaved round-robin so the `COP` branch appears (18 of 372), and
 `DET`/`N` number agreement moved to a guard so generated sentences match the independent checker 372/372.
 `./verify.sh` runs to completion again with sections 31-35 rebuilt on the current driver.
- **Local substitutions with feature-name interfaces (0.0067)**: each rule is evaluated under its own
 substitution; caller constraints are injected by feature name (`fg-seed`) and the callee's resolved
 interface values are unified back (`fg-cmatch`). Two defects that the global-substitution version had are
 now measured as gates: an alpha-renamed declaration rejects `the cats sleeps` (it used to accept it), and
 reusing one nonterminal twice accepts `the cat and the dogs` (it used to reject it). Derived trees are
 restored with an explicit leaf/node split, so 150/150 trees pass the structural checker and 150/150
 linearizations re-parse. Honest limits: the interface does not distinguish parameters from results, so the
 checker verifies structure and leaves only, and feature consistency is covered by re-parsing; an `S`-level
 default is inert (a result with no caller), which is why the teeth gate moved to the `Sbj` default
 (NP third-person singular 0/6 accepted), and the `PRON` branch stays permissive by design.
- **Interface defaults are checked, not only filled (0.0066)**: when the interior binds an interface feature
 and the declaration also gives a default, the two are unified and a mismatch rejects the alternative.
 Measurements hold at 9/9, 150/150 and 150/150, and two deliberately wrong declarations accept 0 of the
 samples (one fills a wrong subject person, one conflicts with the child's 3rd person), which is the
 evidence that the check does work rather than decorate the declaration.
- **Interface feature declarations (0.0065)**: rules may declare `(Cat => ((feature var [default]) ...) kids...)`.
 The default fills a feature the interior leaves unbound, so a noun phrase contributes person 3 without a
 hand-written `bind`. Same measurements as 0.0064 with zero `bind` entries: 9/9 verdict parity with
 `lf-check`, 150/150 generated sentences accepted by it, 150/150 round-trip re-parsed. Boundary: a
 default applies only when the interior leaves the feature unbound, so a wrong interior binding passes;
 a certificate/tree axis from the same declaration was attempted and retracted (kid specs mixed with
 child trees), so it stays open.
- **Single feature-grammar declaration (0.0064)**: `src/meow/fgrammar.l` interprets one declaration
 (leaves carry `(feature var|literal)`, nonterminals may `(bind var literal)`, and `(guard name vars)`
 names a predicate). (0.0064 shipped a `define-form` macro `def-fg`; it was removed in 0.0067 when the interpreter moved
 to a single worker, so today one declaration drives recognizer, generator and certificate checker
 directly.)
 Measured: declaration verdicts match the hardcoded `lf-check` 9/9; 150 generated sentences are
 accepted 150/150 by that independent checker and re-parsed 150/150. Boundaries: nonterminal
 interface features do not propagate automatically (they need an explicit `bind` or a post-expansion
 check), and `a`/`an` selection is absent from both checkers.
- **OOV hypotheses (0.0063)**: morphological suffix rules plus lemma inheritance lift corpus
 derivation 286 -> 396 (+38.5%) at a measured cost of shuffle acceptance 38 -> 55 (+45%). Hypothesis
 count budgets (one / two / lemma / both) do not reduce that cost, so sentence-level context
 agreement (promote a (word, cat) only when two independent contexts require it) is the next axis.
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
