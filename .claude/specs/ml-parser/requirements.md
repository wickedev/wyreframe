# Wyreframe ML Parser Requirements Document

## Introduction

This document defines the requirements for the Wyreframe ML Parser. The ML Parser is a learned, deterministic-at-inference model that converts messy ASCII wireframes (produced by LLMs, hand-drawn input, or recovery-failure cases of the V2 Parser) into the same V2 AST schema that the V2 Parser produces. It is a *robustness layer*, not a replacement: clean V2-syntactic inputs continue to flow through the V2 Parser.

### Document Information

- **Version**: 0.2.0 (Draft)
- **Created**: 2026-06-12
- **Status**: Draft
- **Companion Specs**:
  - `design.md` — architecture, data pipeline, model candidates
  - `self-improvement.md` — training loop, verification metrics
  - `syntax-v2-parser/` — V2 grammar + V2 Parser
  - `v2-renderer/` — AST → HTML (used by self-improvement loop)
  - `v2-ascii-printer/` — AST → ASCII (used by cycle consistency)
  - `verifier/` — three-metric scoring infrastructure (in repo at `src/verifier/`)

### Scope

The ML Parser handles the following:

- Accept arbitrary ASCII text (typically wireframe-like but not necessarily V2-syntactic).
- Emit a V2 AST node (`SceneBlock` / `ComponentBlock` variants from `V2Types`) plus per-node confidence distributions over the categorical attribute vocabulary defined in `design.md §4.1`.
- Coexist with the V2 Parser via a fall-through chain (V2 first → ML on V2 failure).
- Be trained primarily on LLM-native distributions (per `design.md §3`), supplemented by deterministic synthetic augmentation.
- Self-verify its output via the cycle-consistency property (`v2-ascii-printer`) before returning.

The ML Parser does NOT handle the following:

- Parsing of V2-syntactic input that V2 Parser already handles correctly (skipped via fall-through).
- HTML / ASCII output (those are V2 Renderer / V2 Printer's responsibilities).
- Interaction DSL.
- Calling an LLM at runtime (LLMs are training-time teachers only — see Requirement 5).
- Deploying a pretrained language model as the student (see Requirement 6).
- Domain-aware composition (e.g. "this is a Digivice" templates) — see Requirement 4.

---

## Requirements

### Requirement 1: Input Acceptance

**User Story:** As a developer, I want the ML Parser to accept arbitrary ASCII text so that any input the V2 Parser fails on can still be routed through it.

#### Acceptance Criteria

1. WHEN the ML Parser receives a string input THEN it SHALL produce a typed result (success with AST, or typed failure with diagnostics) without runtime crash.
2. The Parser SHALL accept input with mixed line endings (`\n`, `\r\n`, `\r`) and normalize them before inference.
3. The Parser SHALL accept input with non-ASCII characters (Unicode box-drawing, emoji shortcodes) within the V2 syntax vocabulary, and surface a warning for genuinely unrecognized characters rather than crash.
4. WHEN the input exceeds a configured maximum size THEN the Parser SHALL truncate with a warning rather than fail silently.

---

### Requirement 2: Output Schema — V2 AST Compatibility

**User Story:** As a downstream consumer, I want the ML Parser's output to be drop-in compatible with V2 AST so that the V2 Renderer, V2 Printer, and existing tooling can consume it unchanged.

#### Acceptance Criteria

1. WHEN the ML Parser produces an AST THEN that AST SHALL be a valid `V2Types.astNode` value such that `V2Renderer.renderBlockToString` and `V2Printer.printBlock` accept it without runtime error.
2. The output AST node type SHALL be one of the 15 documented V2 variants (Scene, Component, Container, Text, Button, Link, Input, Select, Checkbox, Radio, Divider, String, Emoji, PropPlaceholder, Error).
3. The Parser SHALL preserve `sourceLocation` fields with row/col/offset reflecting the *input* ASCII positions, even when those positions are uncertain (in which case a `data-wf-approximate-location` warning is also emitted).
4. The Parser SHALL emit at most one root block per call. Multi-block input is out of scope (consumers can call multiple times).

---

### Requirement 3: Output Schema — Confidence Distributions

**User Story:** As a downstream consumer (or ML-loop participant), I want the model's confidence distribution exposed per node so that I can apply uncertainty-aware policies (defer, ask, fallback).

#### Acceptance Criteria

1. WHEN the Parser produces an AST THEN it SHALL additionally produce, for each non-Error node, a confidence map over the categorical attribute vocabulary (`design.md §4.1`).
2. The vocabulary SHALL cover at least: `align` (horizontal), `align` (vertical), `layout`, `sizing`, `kind`, `surface`.
3. Each attribute's distribution SHALL be a probability distribution (non-negative reals summing to 1.0 ± floating-point tolerance) over its enumerated categories.
4. The confidence map SHALL be exposed via a separate API field (e.g. `parseWithConfidence(ascii) → {ast, confidence}`), not embedded inside `V2Types.astNode` (preserving V2 AST schema purity per Requirement 2).
5. WHEN argmax confidence for any node attribute falls below a configurable threshold (default 0.55) THEN that node SHALL also appear in the result's `lowConfidenceNodes` list.

---

### Requirement 4: No Domain Registry

**User Story:** As a project maintainer, I want the ML Parser to refuse any domain-specific identification so that the system generalizes to arbitrary ASCII without ever matching named templates.

**Reference**: `design.md §1.1`.

#### Acceptance Criteria

1. The Parser SHALL NOT have any mechanism by which a named domain template (e.g. "digivice", "login-form", "dashboard") triggers special rendering or composition.
2. Training data SHALL NOT include domain labels beyond the universal V2 AST node types in Requirement 2.
3. Inference output SHALL be expressible by purely visual vocabulary (boxes, dots, labels, alignment, distribution, curvature). Any output that requires external domain knowledge to interpret correctly is a defect.
4. Code review SHALL reject pull requests that introduce a domain registry, sprite table, or theme-by-name mechanism into the parser or renderer.

---

### Requirement 5: LLM as Teacher Only

**User Story:** As a project maintainer, I want the ML Parser's runtime to be free of LLM API calls so that inference is fast, offline-capable, and decoupled from third-party services.

**Reference**: `design.md §1.1`, §2.

#### Acceptance Criteria

1. The Parser's inference code path SHALL NOT call any LLM (OpenAI, Anthropic, Google, open-weight LM, etc.).
2. LLMs SHALL only appear in the training-data generation pipeline (`design.md §3`) and in the optional LLM-judge step of the self-improvement loop (`self-improvement.md §3.3`), neither of which runs at deployment time.
3. Build-time gating: the deployed package SHALL NOT include any LLM client library as a runtime dependency.

---

### Requirement 6: No LLM as Student

**User Story:** As a project maintainer, I want the deployed model to be a small, task-specific neural network trained from scratch — not a fine-tune of a pretrained language model.

**Reference**: `design.md §1.1`, §4.2.

#### Acceptance Criteria

1. The deployed model's architecture SHALL be one of the candidates listed in `design.md §4.3–§4.5` (Grid encoder + tree decoder, Sequence tagging + CRF, or Neurosymbolic threshold learning).
2. The model SHALL NOT load pretrained weights from ByT5, GPT-class, Llama, Qwen, Phi, or any other pretrained language model.
3. The deployed model SHALL fit within 100 MB unquantized (target 50 MB), and 25 MB after 8-bit quantization (target 10 MB).
4. The model SHALL be runnable in browser (wasm) and Node.js without GPU.

---

### Requirement 7: Lossy-by-Design Semantic Output

**User Story:** As a downstream consumer, I want the Parser's output to express *semantic intent* (categorical alignment, layout type) rather than raw pixel positions so that the AST maps cleanly to flex/grid CSS.

**Reference**: `design.md §1.1`.

#### Acceptance Criteria

1. The Parser SHALL NOT emit absolute pixel coordinates for content placement.
2. The Parser SHALL prefer categorical values from `design.md §4.1` (e.g. `align = center`) over numeric positions (e.g. `x = 27%`).
3. A fallback escape (e.g. `abs(percentage)`) MAY exist for inputs whose intent cannot be expressed categorically, but SHALL appear in less than 5% of outputs on the production eval set (`real-user`).
4. The Parser SHALL NOT introduce explicit position/alignment override syntax in the input language — disambiguation happens by editing the wireframe (per `design.md §1.1` Out of Scope override syntax).

---

### Requirement 8: V2 Parser Coexistence (Fall-through)

**User Story:** As a developer integrating wyreframe, I want a single `parse(input)` entry point that automatically picks the right backend so I don't have to manage two parsers.

#### Acceptance Criteria

1. The public `parse(input)` API SHALL try the V2 Parser first.
2. WHEN V2 Parser returns `errors.isEmpty == true` AND `containsErrorRecovery == false` THEN the result SHALL be returned unchanged without invoking the ML Parser.
3. WHEN V2 Parser fails or partially recovers THEN the ML Parser SHALL be invoked on the same input.
4. WHEN the ML Parser produces a result AND its self-consistency score (Requirement 9) meets the configured threshold THEN the ML result SHALL be returned with `source: "ml"` annotation and the V2 errors downgraded to warnings.
5. WHEN the ML Parser's self-consistency score falls below the threshold THEN the original V2 result (with its errors intact) SHALL be returned with `source: "v2-fallback"`.

---

### Requirement 9: Self-Consistency Verification at Runtime

**User Story:** As a downstream consumer, I want every ML-produced AST to be verified before it's returned so I never see hallucinated structure that has no grounding in the input.

**Reference**: `self-improvement.md §2`, `src/verifier/`.

#### Acceptance Criteria

1. WHEN the ML Parser produces an AST candidate THEN that candidate SHALL be passed through the cycle-consistency check: `V2Printer.printBlock(ast)` is computed and compared to the input ASCII via the verifier's edit-distance metric.
2. The cycle-consistency score SHALL be exposed on the result.
3. WHEN the cycle score is below the configured threshold (default 0.55) THEN the ML output SHALL be rejected and V2 fallback used (per Requirement 8 #5).
4. The Parser MAY skip pixel-SSIM and region-IoU at runtime (those are training-time signals). Cycle edit distance is the minimum mandatory runtime verification.

---

### Requirement 10: Determinism at Inference

**User Story:** As a developer, I want the ML Parser's output to be deterministic so that snapshot tests, caching, and self-improvement-loop replay all behave predictably.

#### Acceptance Criteria

1. WHEN the ML Parser is called twice with the same input AND the same model weights AND the same options THEN it SHALL produce byte-identical AST output (including identical confidence distributions, within floating-point precision).
2. The Parser SHALL fix all random seeds and sampling parameters at inference time (e.g. greedy decoding, no temperature, deterministic dropout-off).
3. The Parser SHALL be reproducible across processes / machines with the same model checkpoint and the same hardware ISA. Cross-ISA determinism (e.g. ARM vs x86) is a stretch goal, not mandatory.

---

### Requirement 11: Performance

**User Story:** As a developer, I want the ML Parser fast enough to be a fall-through option in interactive editors.

#### Acceptance Criteria

1. The Parser SHALL complete inference on a 50-line wireframe in under 200ms on a current development machine (CPU only, no GPU).
2. The Parser SHALL complete inference on a 500-line wireframe in under 1500ms.
3. Memory usage SHALL stay under 200 MB at peak for any input meeting Requirement 1 #4.
4. WASM-compiled inference SHALL meet the same latency budget within 2×.

---

### Requirement 12: Training Data Quality Gates

**User Story:** As a project maintainer, I want training data to pass deterministic quality checks before being used so that systematic LLM-teacher errors do not pollute the model.

**Reference**: `design.md §3.2`, `self-improvement.md §3` Loops.

#### Acceptance Criteria

1. Every training pair (ASCII, AST) SHALL pass schema validation: the AST satisfies the V2 schema and the ASCII parses to that same AST via the V2 Parser (within semantic equality from `v2-ascii-printer/requirements.md`).
2. Pairs with multi-LLM disagreement on the AST SHALL be routed to the active queue rather than the main training set.
3. The training set SHALL maintain at least 50% LLM-native ASCII (vs synthetic), tracked per epoch.
4. The training pipeline SHALL log and surface the gate-pass rate; sustained drops below 30% SHALL trigger investigation.

---

### Requirement 13: Calibrated Confidence

**User Story:** As a downstream consumer relying on confidence-based policies, I want the model's stated probabilities to roughly match real correctness rates so the threshold mechanism is meaningful.

#### Acceptance Criteria

1. On the gold eval set, the model's expected calibration error (ECE) SHALL be ≤ 0.10 (10 bins).
2. The training pipeline SHALL include a calibration check after each epoch and SHALL emit a reliability diagram.
3. WHEN ECE exceeds threshold on the latest checkpoint THEN a temperature-scaling post-processor SHALL be re-fit before deploy.

---

### Requirement 14: Evaluation Coverage

**User Story:** As a project maintainer, I want a fixed evaluation suite that catches regressions before deploy.

**Reference**: `design.md §6`, `self-improvement.md §4.7`.

#### Acceptance Criteria

1. The eval suite SHALL contain four hold-out sets: `clean-v2` (V2-parseable), `synthetic-broken` (deterministic noise), `llm-broken` (LLM-native), and `real-user`.
2. The `real-user` set SHALL be sealed and human-labeled; it SHALL NOT contribute training signal.
3. A new model checkpoint SHALL pass *no regression* on all four sets relative to the current production model before being deployed.
4. Eval metrics SHALL include: exact AST match rate, structural F1, label edit distance, cycle-consistency rate, and confidence calibration ECE.

---

### Requirement 15: Public API Compatibility

**User Story:** As an existing wyreframe consumer, I want the ML Parser to be additive — I should be able to ignore it or opt in without breaking change.

#### Acceptance Criteria

1. The V2 Parser's existing public API (`parse`, `parseBlock`, etc.) SHALL remain unchanged.
2. The combined fall-through API SHALL ship under a new export path (e.g. `wyreframe/parse` or `wyreframe/ml-parser`), preserving the existing `wyreframe/parser/v2` for direct V2-only access.
3. The ML model file (weights, vocabulary, calibration table) SHALL be an opt-in package dependency or download — consumers who only want V2 should not pay the bundle cost.
4. TypeScript types for the ML Parser API SHALL include the confidence schema (Requirement 3).

---

## Open Questions

1. **Maximum input size**: What is the upper bound for a single parse call? Recommendation: 10,000 characters (rows × cols). Beyond that → truncate with warning.
2. **Multi-block input**: Currently scoped out; if real-world LLMs produce multi-scene outputs, should we add a `parseAll(input) → array<ast>` convenience? Defer until evidence.
3. **Tree decoder vs sequence labeler choice timing**: Should we pick A or B before training starts, or train both in parallel and pick by eval? `design.md §4.6` says train both — Requirement 6 implicitly accepts either.
4. **WASM build pipeline**: Which ONNX/TFLite/custom runtime? Decision deferred to `tasks.md` Phase 10 (Public API).
5. **Confidence calibration on small models**: BiLSTM-CRF historically under-confident; temperature scaling may need a different recipe vs grid transformer. To be revisited after Phase 5/6 results.
6. **Real-user dataset license**: User-submitted wireframes for training need consent / license. Out of scope of this requirements doc but flagged for legal.
7. **Cycle threshold tuning**: Default 0.55 (Requirement 9) is a guess. Should be tuned empirically once `real-user` has ≥100 labeled samples.
