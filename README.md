# meowdlm - deductive learning experiment (Maru / LLVM IR native inference)

Same conversation task as the original MeowLLM (3.45M parameters, gradient training), solved
without gradients. Judgement, derivation, generation and persistence run in Maru (an LLVM IR
Lisp); Python remains only for web fetching and data conversion.

```text
src/meow/*.l        Maru-native model (kernel, evidence, grammar, features, certificates, state)
data/*.l            static data (some files are sources - see data/README.md)
tools/              data converters + S-expression sorter (sx.py)
tools/fetch/        web collection (the Python-permitted area) -> cache/ (git-ignored)
experiments/parity  drivers and Python-reference differentials
tests/              Maru self-tests
docs/               release records, including negative results and retractions
```

## Running

```bash
cd meowdlm_v0.0053
MARU=/research/dlm_v0.0284/maru-compiler ./verify.sh    # 21 sections, 31 gates, ~13 min
```

`verify.sh` differentially checks the kernel, grammar, evidence, surface realization, rule
invention, feature grammar, certificates, state persistence and OOD abstention.

## Current performance (same 170 probes)

| axis | meowdlm 0.0053 | original MeowLLM (step 2000) |
|---|---|---|
| category judgement (in-domain, 150) | **105/150 = 0.700** | 70/150 = 0.467 |
| out-of-domain abstention (20) | 3/20 (16/20 with the 0.25 gate) | 0/20 |
| new OOD fixture abstention (20) | **20/20** (0.25 gate) | - |
| parameters / gradient steps | **0 / 0** | 3,447,552 / 2000 |
| evidence tracing | proof chains, counterexample paths | none |

## Honest status (read before judging)

- **Established**: judgement (0.700), feature grammar (person/number/case, 21/21), kernel queries
  (20/20), sentence derivation (286/1000 corpus sentences), evidence decisions (170/170 against the
  Python reference), state persistence (pre-load hash check, atomic commit, journal replay), OOD
  cue-hit gate.
- **Not established**: phrase-structure **rule invention** (0.0048: zero training gain after the
  S-recursion collapse was fixed), **natural generation** (2/15 surface categories pass this
  project's own grammar), OOV absorption (character-similarity mapping is harmful: -3.1 to -6.2 pp).
- **Unfinished**: surface <-> syntax wiring, certify.l 6-tuple conversion, journal re-serialization
  and tmp cleanup, wiring the OOD gate into the default path.

Retracted numbers stay in `docs/release-0045..0048.md` with the reasons (the invention figures in
0.0045/0046/0047 mixed an S-recursion collapse and an alphabetical-category bias, so they were
withdrawn).

## Boundaries

- The corpus has 201 unique inputs and 554 vocabulary items. Convergence on open-domain English is
  unverified.
- The new OOD fixture (20 items) was written inside this project; it is not an external benchmark.
- FNV-32 detects accidental corruption only; adversarial tampering needs a separate manifest.
- The Maru runtime is an external binary (`/research/dlm_v0.0284/maru-compiler`).
