# meowdlm

**A deductive-learning dialogue model.** meowdlm learns a chat persona by *inducing an explicit
axiom basis* from a small dialogue corpus — zero gradient steps, no neural network, no GPU — and
answers by kernel closure over that basis. It is evaluated head-to-head against the original
MeowLLM transformer on identical probes.

The original model, its persona dataset and its tokenizer come from
**[phanii9/MeowLLM](https://github.com/phanii9/MeowLLM)**. Everything in this repository that is
compared *against* that model uses the upstream code and the published checkpoint; the deductive
side is this repository's own.

The point of the project is not the chatbot. It is the question: *how far does a deductive
learning structure get on a task that is normally solved by gradient descent?* Every release
measures one structural change against a control, and reports the null results too.

```
corpus ──▶ cue induction ──▶ axiom basis (discrete, versioned)
                                    │
probe  ──▶ multi-layer evidence ──▶ decision rule ──▶ answer | abstain(reason)
                                                          │
                                                    proof trace
```

## Status

| version | change | free-text | out-of-scope | 2-turn | gate |
|---|---|---|---|---|---|
| 0.0002 | DLM 0.0284 structural port (basis / dependency graph / d-select / conservation) | 0.487 | 0.650 | 0.520 | `V0002-MEOWDLM-DLM0284-PASS` |
| 0.0003 | cue abstraction (gapped patterns, sub-word cues) | 0.493 | 0.650 | 0.540 | `V0003-MEOWDLM-ABSTRACTION-PASS` |
| 0.0004 | evidence layer (Silicon fold/unfold, Rocq instance priorities, Screamer constraints) | 0.520 | 0.650 | 0.620 | `V0004-MEOWDLM-EVIDENCE-PASS` |
| 0.0005 | variable abstraction + alignment admission (LGG) | 0.560 | 0.650 | 0.600 | `V0005-MEOWDLM-LGG-PASS` |
| **0.0006** | **parity release: answer-rate fallback ladder + compositional responses** | **0.640** | 0.000 / **0.600** | **0.600** | `V0006-MEOWDLM-PARITY-PASS` |

Each row reports that release's primary configuration. For 0.0003 the primary claim was the null
result, so the row shows the best arm; for 0.0004 and 0.0005 it is the `priority` arm.

Reference row: the original MeowLLM checkpoint (3,447,552 parameters, 2000 gradient steps) scores
**0.467** free-text and **0.000** out-of-scope on the same probe.

## Head-to-head with the original MeowLLM

Same probe, same scoring function, different learning path. The original
([phanii9/MeowLLM](https://github.com/phanii9/MeowLLM)) uses its own published checkpoint; meowdlm
never opens that checkpoint (see `docs/release-0002.md` and the audit hook in
the 0.02xx line).

| model | learning | parameters | free-text | out-of-scope | 2-turn |
|---|---|---|---|---|---|
| MeowLLM (own checkpoint, greedy decode) | 2000 gradient steps | 3,447,552 | 0.467 (70/150) | 0.000 (0/20) | — |
| **meowdlm 0.0005** | 197 axioms + 24 LGG patterns, **0 gradient steps** | **0** | **0.560** (84/150) | **0.650** (13/20) | 0.600 |

```
paired McNemar: meowdlm-only 33, original-only 19, p = 0.0704   (borderline, not significant)
decision mix:   derived 95, lgg 15, no_evidence 26, unknown 14
```

Honest reading: a 9.3 pp lead that is **not** significant at the 5% level, plus a large lead on
out-of-scope handling. The statistically significant gain in this line is internal: turning the LGG
layer on moves 6 items and loses none (McNemar p = 0.0312).

## Parity with the original MeowLLM

Stated goal: **equal or better on every axis, with learning that uses no GPU.** Thirteen axes are
measured for both models on the same probe by `eval/parity_matrix.py`; cost axes are wall-clock and
RSS measurements, trust axes are artifact checks.

Two policies are shipped, because they trade against each other:

```
C  always-answer : answer with the best candidate even without evidence
                   (proto fallback → forced → majority default)
B  clarify       : ask for clarification when no evidence exists (keeps out-of-scope detection)
```

| axis | original | C always-answer | verdict | B clarify | verdict |
|---|---|---|---|---|---|
| in-scope accuracy | 0.467 | **0.640** | better | 0.620 | better |
| answered precision | 0.467 | **0.640** | better | 0.684 | better |
| answer rate (no refusal) | 1.000 | **1.000** | equal | 0.907 | behind |
| out-of-scope clarify | 0.000 | 0.000 | equal | **0.600** | better |
| 2-turn accuracy | 0.300 | **0.600** | better | 0.620 | better |
| novel response rate | 0.080 | **0.300** | better | 0.324 | better |
| response distinct ratio | 0.360 | **0.960** | better | 0.956 | better |
| response provenance | 0.920 | **1.000** | better | 1.000 | better |
| utility (correct in-scope or clarified out-of-scope) | 0.412 | **0.565** | better | **0.618** | better |
| inference latency (ms) | 25.4 | **0.11** | better | 0.13 | better |
| learned parameters | 3,447,552 | **0** | better | 0 | better |
| gradient steps | 2,000 | **0** | better | 0 | better |
| trace rate | 0.000 | **1.000** | better | 1.000 | better |

```
C always-answer: 13 of 13 axes equal or better
B clarify      : 12 of 13 (answer rate trades against out-of-scope detection)
paired McNemar  in-scope, C vs original: meowdlm-only 40, original-only 14, p = 0.0005
training cost   axiom induction + LGG: 2.8 s on CPU, 0 parameters, 0 gradient steps
```

The in-scope accuracy lead is now **statistically significant** (p = 0.0005); in 0.0005 it was not.
Policy C reaches parity by answering everything; policy B keeps a 0.600 out-of-scope clarify rate and
a higher utility, at the cost of the answer-rate axis. Both are one environment variable apart.

What closed the three previously behind axes:

| axis | before | now | mechanism |
|---|---|---|---|
| answer rate | 0.733 | **1.000** | fallback ladder: proto fallback → forced → majority default |
| novel response rate | 0.000 | **0.300** | response frames with entity slots filled from the input |
| in-scope accuracy | 0.560 | **0.640** | the fallback recovers 26 of the 40 previous refusals |

## Residual gaps

Under policy C, two of fifteen categories still favour the original.

| category | meowdlm | original |
|---|---|---|
| affection | 1/10 | **3/10** |
| humans | 6/10 | **7/10** |

```
items the original wins outright: 14 of 150 (affection 4, humans 3 account for half)
example mis-derivations: "i love you so much" -> dogs, "come get some cuddles" -> vacuum
```

`affection` failures are confident mis-derivations: instance priority pulls those utterances toward a
neighbouring category. One mis-induced axiom redirects every question whose cues it captures, which
makes the failure systematic and traceable — and still wrong.

Two honest boundaries on the parity claim:

1. **Policy C gives up out-of-scope detection** (0.600 → 0.000) to match the answer-rate axis.
   Policy B keeps it and scores higher utility (0.618 vs 0.565). The axis parity is real; it is
   bought with a policy decision, and the table shows the price.
2. **Novel-response quality is unvalidated.** Composition substitutes an entity into a corpus frame,
   so the grammar stays inside the frame, but semantic aptness was not independently judged.

## How learning works

```text
1  records     6,000 train + 1,000 val persona turns
2  cues        content-word 1–3 grams, morphological normalisation, response-side cues
3  axioms      (cue → category) units admitted by support and negative coverage  → 197 units
4  LGG         column-wise anti-unification over same-length record pairs;
               admission = alignment + zero negative coverage + adjunction check  → 24 patterns
5  basis       versioned store (activate / deactivate / rollback / dedupe); inactive units never fire
6  inference   closure over active units, then a decision rule:
               follow-up state → LGG layer → out-of-scope guard → instance priority
7  answer      selected from the admitted response pool of the derived category (conservation)
```

Nothing here is trained by descent. The "weights" are an inspectable list of patterns with support
counts and evidence record ids.

## Evidence layer, and where it came from

The evidence design is borrowed from three verification systems, and from earlier DLM releases
recovered from a source backup.

| source | mechanism | module |
|---|---|---|
| Silicon (Viper) | predicate fold / unfold — a definition's body is a set of surface forms | `src/evidence.py` |
| Rocq (Coq) | instance / hint table with priorities and deterministic, auditable resolution | `src/evidence.py` |
| Screamer | finite domains, constraints, all-values enumeration, ambiguity reported | `src/infer.py` |
| `dlm_v0.0110/src/dlm/d107-learn.l:22` | "structure, not content" — distinct constants become variables | `src/lgg.py` |
| `dlm_v0.0110/src/dlm/d107-learn.l:30-64` | pair/triple pattern generation, alignment-based admission, support by distinct records | `src/lgg.py` |
| `dlm_v0.0017/dlm/deductive.py:626` | column-wise LGG that preserves argument correspondence | `src/lgg.py` |
| `dlm_v0.0031/dlm/galois.py:1-40` | LGG ⊣ closure adjunction; over-generalisation counterexamples | `src/lgg.py` |
| DLM 0.0284 `basis.l`, `axiom-graph.l`, `deduce.l`, `proof.l` | versioned basis, dependency graph + DCE, subset selection by coverage/no-false-coverage, proof-carrying derivation | `src/basis.py`, `src/axiomgraph.py`, `src/induct.py`, `src/infer.py` |

## Repository layout

```
src/basis.py         versioned axiom store (activate, deactivate, rollback, CSE)
src/axiomgraph.py    dependency graph, reachability, DCE, dependent re-validation
src/induct.py        axiom induction and admission (support, purity, negative coverage)
src/lgg.py           variable abstraction, anti-unification, adjunction check
src/evidence.py      predicate fold/unfold, instance priorities, frame table
src/infer.py         closure, decision rules, abstain reasons, answer conservation
eval/run_eval.py     probe evaluation (free text, out-of-scope, 2-turn, conflicts, conservation)
eval/arms0005.py     4-arm comparison with paired significance tests
eval/risk_coverage.py  precision at matched coverage (selective-prediction quality)
eval/retract.py      retraction locality (dependent re-validation)
eval/devselect.py    thresholds selected on split A, reported on split B
eval/compare_original.py  head-to-head against the original MeowLLM checkpoint
eval/gaps.py         per-category gaps, abstention bucket, novel-string capability, 2-turn
eval/parity_matrix.py    13-axis parity measurement for both models
eval/parity_two_configs.py  parity table for the always-answer and clarify policies
eval/abstraction_diag.py  generated-vs-admitted cue counts, out-of-vocabulary absorption rate
data/                dialogue corpus, induced basis, LGG patterns, sha256 manifests
probe/               free-text probe (150 in-scope + 20 out-of-scope), 2-turn probe (50)
docs/                per-release notes incl. failed hypotheses (release-0006.md = parity release)
verify.sh            release gate
```

## Quickstart

```bash
./verify.sh                       # full gate; prints V0005-MEOWDLM-LGG-PASS
python3 src/induct.py             # learn axioms        (deterministic)
python3 src/lgg.py                # learn LGG patterns   (deterministic)
python3 eval/run_eval.py          # evaluate on the probe
python3 eval/compare_original.py  # head-to-head with the original checkpoint
```

Arm selection is environment-driven, so every claim can be re-run as its own control:

```bash
DECISION=sum      python3 eval/run_eval.py     # weighted sum + margin (control)
DECISION=priority LGG=0 python3 eval/run_eval.py  # instance priority, no LGG
DECISION=priority LGG=1 python3 eval/run_eval.py  # instance priority + LGG
DECISION=allvals  python3 eval/run_eval.py     # Screamer all-values (ambiguous → clarify)
CUE_MODE=base|gap|char|gap+char python3 eval/run_eval.py

# parity policies
ANSWER_ALL=1 LAST_RESORT=1 python3 eval/parity_matrix.py   # policy C: always answer
ANSWER_ALL=0 LAST_RESORT=1 python3 eval/parity_matrix.py   # policy B: clarify when no evidence
COMPOSE=0 FALLBACK=0 python3 eval/run_eval.py              # ablate composition and fallback
```

## What the gates enforce

```text
reproducible learning   identical basis and LGG artifact hashes across runs
structure tests         basis versioning / rollback, dependency check, DCE, duplicate merge
adjunction law          every admitted LGG pattern satisfies "p covers S ⟺ p ≥ LGG(S)"
retraction locality     deactivating one category drops that category only (others Δ = 0)
answer conservation     no response outside the admitted pool of the derived category
honest reporting        the documents must state whichever side actually won
```

## Known limits

- The corpus has 201 distinct inputs and a 225-word vocabulary. Probe tokens are 27% out-of-vocabulary,
  so surface-matching systems have a hard ceiling here. Sub-word cues absorbed **0.0%** of that
  vocabulary gap (`docs/release-0003.md`).
- LGG patterns only arise from same-length record pairs, which caps probe firing at about 10%.
- Parity in policy C is bought by answering everything; out-of-scope detection moves to policy B.
- Adding a human-curated synonym dictionary lifts the score to 0.713, but that dictionary was
  written while looking at the probe. It is excluded from this release and reported as a separate,
  weaker-evidence condition (`docs/release-0002.md`).
- The comparison against the original uses one published checkpoint (step 2000).

## Feedback into DLM

The point of the exercise is to return the structures that worked to the deductive model line. The
feedback pack, with the evidence that motivates each item:

| item | evidence | target in DLM |
|---|---|---|
| fallback ladder (no evidence → best candidate → default) | accuracy 0.560 → 0.640; McNemar p = 0.0005 | decision layer gains `fallback` and `default` reasons; clarification restricted to out-of-domain |
| LGG admission (alignment + zero negative coverage + adjunction) | 24 of 68 candidates admitted; 15/15 firing precision; p = 0.0312 | an `lgg` stage before `basis.l`, with the adjunction check beside `ag-check-deps` |
| response composition (definition frame + entity substitution) | novel rate 0.000 → 0.300 | explicit entity slots in definitions; substitutions re-checked by conservation |
| parity matrix as a gate | 13 axes, per-axis verdicts | release gates must assert per-axis parity rather than a single score |

## Data and attribution

The baseline this project is measured against is **[phanii9/MeowLLM](
https://github.com/phanii9/MeowLLM)** — the original MeowLLM transformer, its persona dialogue data
and its BPE tokenizer all come from that repository. Upstream is cloned read-only at
`/research/MeowLLM`; `meow/model.py`, `data/tokenizer.json` and the published weights
(`https://huggingface.co/hunt3rx99/meowllm`, `best.pt`) are used **only to evaluate the original
against itself**.

The dialogue corpus and probe in this repository are derived from the upstream persona dataset;
`data/sources.sha256` and `data/manifest.sha256` record the digests. The deductive side never reads
the upstream weights or tokenizer — the audit hook in the 0.02xx line enforces that by failing on
any such file access.

If you build on this work, cite the upstream project as the source of the task, the data and the
baseline numbers:

```
Original model and dataset:  https://github.com/phanii9/MeowLLM
Published weights:           https://huggingface.co/hunt3rx99/meowllm
```
