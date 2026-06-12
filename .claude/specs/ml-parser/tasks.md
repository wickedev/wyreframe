# Wyreframe ML Parser — Implementation Tasks

## Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Implements**: `requirements.md` + `design.md` + `self-improvement.md` in this directory
- **Style**: Phased; each task aims to be a single PR. `[requires: T#]` / `[blocks: T#]` track dependencies. Acceptance criteria are independently verifiable.

---

## Current Status & Pause Point

| | |
| --- | --- |
| **Last completed** | P0 prerequisites — V2 Renderer (`e74bdd2`), V2 ASCII Printer (`e74bdd2`), Visual Verifier (`5475252`) |
| **In progress** | — (paused) |
| **Next up** | P1 Data Pipeline (LLM corpus collection + labeling). CPU-only; doesn't need GPU. |
| **Hardware blocker** | P3+ (model training) waits on **NVIDIA DGX Spark setup** (GB10 Grace Blackwell). Until then, only P0–P2 are runnable on a regular machine. |
| **Resume strategy** | When DGX Spark is online: revisit this file, then either (a) start P1+P2 on dev machine in parallel with DGX setup, or (b) pick up at P3 directly if P1/P2 already done. |

> **Note on parallelizability without DGX Spark**: P1 (LLM API calls), P2 (deterministic noise injection), P0.4 (conformance test), P0.5 (gold eval skeleton) can all proceed without a training GPU. They produce datasets and tooling that P3+ will consume. Whoever resumes this work should check whether those can be advanced first.

---

## Phase Summary

| Phase | 목적 | Tasks | 합격선 |
| --- | --- | --- | --- |
| **P0 — Prerequisites** | 결정적 인프라 준비 | T0.1 ~ T0.5 | V2 Renderer/Printer/Verifier 완성 + conformance 검증 |
| **P1 — Data Pipeline (LLM corpus)** | LLM-native ASCII 수집 + 라벨링 | T1.1 ~ T1.6 | 1k 합격 페어, 게이트 통과율 ≥30% |
| **P2 — Synthetic Augmentation** | V1 렌더러 기반 결정적 노이즈 데이터 | T2.1 ~ T2.4 | 합성셋 ≤50% 비중, 라벨 100% 정확 |
| **P3 — Model A: Grid encoder + tree decoder** | 1순위 모델 아키텍처 | T3.1 ~ T3.6 | smoke 학습 → `clean-v2` ≥95% AST 일치 |
| **P4 — Model B: Sequence tagging + CRF** | 경량 backup 모델 | T4.1 ~ T4.5 | smoke 학습 → `clean-v2` ≥90% |
| **P5 — Bootstrap Loop B (Distillation)** | self-improvement 가동 | T5.1 ~ T5.4 | 50k 페어 누적, `llm-broken` ≥70% |
| **P6 — Loop A (Cycle consistency)** | cycle 신호를 학습에 주입 | T6.1 ~ T6.3 | cycle metric 활용으로 +5pp 이상 개선 |
| **P7 — Loop C (LLM Judge)** | 미묘한 의미 오류 잡기 | T7.1 ~ T7.3 | judge 평균 점수 ≥7 |
| **P8 — Loop D (Active learning)** | 어려운 케이스 우선 학습 | T8.1 ~ T8.3 | low-confidence 처리율 ≥60% |
| **P9 — Runtime integration** | V2 ↔ ML fall-through | T9.1 ~ T9.4 | `real-user` 셋에서 V2 단독 대비 +20pp |
| **P10 — Public API / packaging** | npm 배포 가능 상태 | T10.1 ~ T10.5 | 외부 import + wasm 추론 < 200ms (50줄) |

---

## Phase 0 — Prerequisites

대부분 이미 완료. 본 phase는 ML 학습이 아니라 *결정적 인프라*의 마지막 점검.

### T0.1 — V2 Renderer 완성 ✅ (이미 완료)
- 상태: `src/renderer/v2/` 구현 + 54 tests pass (commit `e74bdd2`)
- **AC**: 충족됨

### T0.2 — V2 ASCII Printer 완성 ✅ (이미 완료)
- 상태: `src/printer/v2/` 구현 + 40/40 round-trip pass (commit `e74bdd2`)
- **AC**: 충족됨

### T0.3 — Visual Verifier 완성 ✅ (이미 완료)
- 상태: `src/verifier/` 구현 + 46 tests pass (commit `5475252`)
- **AC**: 충족됨

### T0.4 — Cross-component Conformance 테스트
- 모든 15개 V2 AST variant에 대해 V2 Parser → V2 Renderer + V2 Printer → V2 Parser 라운드트립이 정합한지 단일 슈트에서 검증
- 발견되는 syntax 미정 항목은 `docs/syntax-v2.md` 정합 PR로 분리
- **AC**:
  - 15개 variant × {Renderer, Printer} = 30 케이스 모두 통과
  - V2 Parser → V2 Printer → V2 Parser의 의미 등가성 100%
  - V2 Renderer가 같은 AST에 대해 byte-identical HTML 생성 (이미 determinism test로 보장됨)

### T0.5 — Gold Eval Skeleton
- 평가셋 4종 디렉터리/스키마 초기화: `eval/{clean-v2,synthetic-broken,llm-broken,real-user}/`
- 평가 스크립트 진입점 (모델 없이도 "empty model"로 호출 가능한 placeholder)
- 메트릭 함수 (exact AST match, structural F1, label edit distance, cycle rate, ECE)
- **AC**:
  - `clean-v2`에 V2 Parser 기존 fixture에서 200개 자동 추출
  - `synthetic-broken` 1k 자동 생성 가능 (V2 Printer + 노이즈 함수)
  - eval CLI: `npm run eval -- --model empty --set clean-v2` 동작 (모두 0점 baseline)

---

## Phase 1 — Data Pipeline (LLM corpus)

### T1.1 — Scenario Meta Sampler [blocks: T1.2]
- design.md §3.4 메타 변수 공간 (도메인/디바이스/복잡도/패턴/표기 변주)
- cartesian product + 결정적 시드로 시나리오 N개 생성
- 출력: JSON 시드 (LLM 프롬프트 슬롯에 주입할 형태)
- **AC**:
  - 5축 × 평균 4값 = 1000+ 고유 시나리오 생성 가능
  - 같은 시드 → 같은 시퀀스 (결정적)

### T1.2 — LLM Multi-vendor Collector [requires: T1.1] [blocks: T1.3]
- 4종 LLM 어댑터 (OpenAI, Anthropic, Google, 오픈웨이트 via OpenRouter 등)
- 각 LLM에 시나리오 주입 → ASCII 출력 수집 (AST는 함께 요구하지 않음, 자연스러운 깨짐 보존)
- 결과를 `data/llm-corpus/<vendor>/<scenario-hash>.txt` 형태로 저장
- **AC**:
  - 4 vendor × 50 시나리오 = 200 ASCII 샘플 수집 데모
  - 모든 출력 raw 상태 보존 (정규화/필터 없음)
  - rate limit 핸들링, 재시도 로직

### T1.3 — LLM Multi-vote AST Labeler [requires: T1.2] [blocks: T1.4]
- 강한 LLM(GPT-4-class / Claude-Opus-class)에 각 ASCII를 V2 AST로 변환 요청 N=3~5회
- AST 의미 비교 (`v2-ascii-printer`의 `Compare.semanticallyEqual` 재사용)
- 다수결 수렴 시 채택, 불일치는 active queue로
- **AC**:
  - 200 샘플에 대해 다수결 ≥3/5 수렴율 측정
  - 불일치 라우팅 동작
  - 라벨이 V2 AST 스키마 검증 통과

### T1.4 — Round-trip Self-consistency Gate [requires: T1.3] [blocks: T1.5]
- 라벨된 (ascii, ast) 페어에서 V2 Printer로 ast → ascii' 생성
- 구조 시그니처 비교 (컨테이너 개수/깊이/자식 분포)
- 임계치 미달 시 폐기 또는 review queue
- **AC**:
  - 통과율 측정 (목표 ≥30%)
  - 통과 페어가 `verifier.cycleEditDistance` 점수 ≥0.7

### T1.5 — Cross-model Audit [requires: T1.4]
- 다른 LLM이 (ascii, ast) 페어를 yes/no 판정
- 동의하지 않는 페어는 human queue
- **AC**:
  - audit 통과율 측정
  - 의견 충돌 케이스가 human queue로 정상 라우팅

### T1.6 — Human-in-the-loop UI (최소 버전) [requires: T1.5]
- 라벨러가 review queue 페어를 확인 / 정정할 수 있는 최소 인터페이스
- 결정 결과를 학습 셋에 편입
- **AC**:
  - 100개 케이스 라벨링 가능
  - 인터페이스 기록이 reproducible (감사 추적)

---

## Phase 2 — Synthetic Augmentation

### T2.1 — Canonical AST Generator [blocks: T2.2]
- V2 AST를 프로그램으로 합성하는 빌더 (다양한 컨테이너 깊이, 자식 수, 노드 mix)
- 시드 기반 결정적
- **AC**:
  - 100개의 다양한 깊이/너비 AST를 1초 안에 생성
  - 모든 결과가 V2 AST 스키마 검증 통과

### T2.2 — Deterministic Noise Injector [requires: T2.1]
- design.md §3.3 노이즈 종류 모두 구현: 1칸 border 어긋남, corner 누락, indent ±1, CRLF 혼합, width inconsistency, label typo
- 노이즈 강도 파라미터화
- **AC**:
  - 같은 (AST, noise-seed) → 같은 ASCII 출력
  - 각 노이즈 종류별 단위 테스트
  - 노이즈 적용 후 V2 Parser가 *실패*하는 비율 측정 (목표 ≥50%, 즉 ML이 실제로 풀어야 할 영역)

### T2.3 — Augmentation Mix Controller [requires: T2.2]
- LLM-native vs synthetic 비중 캡 (≥50% LLM-native)
- 학습 셋 정의 파일 (yaml/json)
- **AC**:
  - 50k 셋 구성 시 비중 정확
  - reproducible (셋 정의 → 같은 페어 시퀀스)

### T2.4 — Synthetic-Broken Eval Set [requires: T2.2]
- `eval/synthetic-broken/` 에 1k hold-out
- 학습 셋과 시나리오 시드 단위로 분리
- **AC**:
  - hold-out leakage 없음 (시드 분리 검증 테스트)

---

## Phase 3 — Model A: Grid encoder + tree decoder

### T3.1 — Tensor Encoder for ASCII Grid [blocks: T3.2]
- ASCII → 2D 그리드 (rows × cols × char_vocab) 텐서
- 패딩, masking, position embedding
- **AC**:
  - 50줄 / 200 col 입력 < 10ms encoding (CPU)
  - 결정적

### T3.2 — Grid Encoder Architecture [requires: T3.1] [blocks: T3.3]
- axial transformer 또는 small CNN backbone (ConvNeXt-tiny 규모)
- 10~50M 파라미터 목표
- 사전학습 LM 절대 사용 안 함 (requirements.md Requirement 6)
- **AC**:
  - 모델 카운트가 50M 이하
  - 임의 입력에서 forward pass 성공
  - 임의 가중치로 단위 테스트 통과

### T3.3 — Tree Decoder [requires: T3.2] [blocks: T3.4]
- V2 AST를 깊이 우선 순회로 토큰화하는 vocabulary
- autoregressive decoder + 카테고리 헤드 (requirements §3 confidence)
- **AC**:
  - 토큰화 → 역토큰화 라운드트립 100% (학습 없이)
  - 빈 모델로 forward pass 성공

### T3.4 — Training Loop (PyTorch) [requires: T3.3] [blocks: T3.5]
- 데이터 로더, 옵티마이저, loss (cross-entropy on token + auxiliary loss on confidence calibration)
- checkpoint 저장/복원
- **AC**:
  - 1k 페어 1 epoch < 30분 (CPU 또는 단일 GPU)
  - checkpoint 저장 후 로드 시 byte-identical inference

### T3.5 — Smoke Training [requires: T3.4, P1, P2]
- 1k 페어로 첫 학습
- gold eval 평가
- **AC**:
  - `clean-v2` ≥95% AST match
  - 학습 곡선이 발산 없이 수렴

### T3.6 — Inference 결정성 & 양자화 사전 점검 [requires: T3.5]
- greedy decoding 결정성 확인
- 8-bit 양자화 후 정확도 손실 측정
- **AC**:
  - 같은 입력 × 50회 → byte-identical 출력
  - 양자화 후 `clean-v2` 정확도 손실 ≤2pp

---

## Phase 4 — Model B: Sequence tagging + CRF

### T4.1 — Cell Vocabulary 설계 [blocks: T4.2]
- 각 (row, col) 셀의 태그 vocabulary: `border-h / border-v / corner-tl / interior / text-char / bracket-open / bracket-close / ...`
- AST → 셀 태그 시퀀스 변환 (정답 라벨 생성 함수)
- **AC**:
  - 1k AST에 대해 변환 라운드트립 (라벨 → AST 재구성) 100% 성공

### T4.2 — BiLSTM-CRF 또는 작은 transformer [requires: T4.1] [blocks: T4.3]
- 1~5M 파라미터
- CRF 상위 레이어 또는 transition matrix
- **AC**:
  - 모델 카운트 ≤5M
  - 임의 입력에서 inference 성공

### T4.3 — AST 후처리 조립기 [requires: T4.2]
- 태그 시퀀스 → V2 AST 결정적 변환
- V2 휴리스틱의 일부 재활용 가능 (post-process logic)
- **AC**:
  - 정답 태그 시퀀스 → 정답 AST 100%
  - 노이즈 있는 태그 시퀀스에 대한 graceful recovery

### T4.4 — Training Loop [requires: T4.2, P1, P2]
- CRF NLL loss + 태그별 cross-entropy
- **AC**: 1k 페어 1 epoch < 10분 (CPU)

### T4.5 — Smoke Training [requires: T4.3, T4.4]
- `clean-v2` ≥90% AST 일치 합격선
- A/B 비교 (T3.5 vs T4.5)
- **AC**:
  - 학습 수렴
  - 모델 사이즈 / 정확도 / 추론 시간 트레이드오프 표 작성

---

## Phase 5 — Bootstrap Loop B (Distillation)

### T5.1 — Self-improvement Orchestrator [requires: P1, T3.5 또는 T4.5]
- self-improvement.md §3.2 Loop B 구현
- batch 단위로: LLM 생성 → 모델 추론 → verifier 점수 → 통과 페어 학습 큐
- **AC**:
  - 1 iteration end-to-end 동작
  - 통과율 / 학습 진행 로그

### T5.2 — Continuous Training Manager [requires: T5.1]
- N 페어 누적 시 1 epoch 학습 → eval → deploy or rollback
- **AC**:
  - 10 iteration 자동 실행
  - eval 회귀 시 자동 rollback

### T5.3 — 50k 페어까지 확장 [requires: T5.2]
- 데이터셋 누적 50k
- `llm-broken` ≥70% 목표
- **AC**: 합격선 달성, 학습 곡선 plateau 모니터링

### T5.4 — 비중 모니터링 [requires: T5.3]
- LLM-native ≥50% 유지 자동 점검
- distribution drift 감지 알람
- **AC**: 매 epoch 비중 표/그래프 자동 생성

---

## Phase 6 — Loop A (Cycle consistency)

### T6.1 — Cycle 신호 학습 통합 [requires: P5]
- `verifier.cycleEditDistance`를 추가 loss term으로 통합
- weighting 튜닝
- **AC**: ablation 으로 cycle loss 추가 시 metric 개선 확인

### T6.2 — Trivial cycle 방지 [requires: T6.1]
- cycle만으로 trivial solution 수렴 방지
- 다른 loss와의 조합 강제
- **AC**: cycle loss 전용 학습으로 mode collapse 확인 후 강건 mix 결정

### T6.3 — Cycle 통합 평가 [requires: T6.2]
- 모든 eval set에서 cycle 추가 전후 비교
- **AC**: 합산 +5pp 이상 개선 또는 미달 사유 문서화

---

## Phase 7 — Loop C (LLM Judge)

### T7.1 — Multimodal Judge Adapter [blocks: T7.2]
- `self-improvement.md §3.3` prompt template 구현
- HTML 스크린샷 (`v2-renderer` + headless browser) + ASCII 텍스트 입력
- judge response parsing
- **AC**: 100 sample judge 호출 + 응답 파싱 100%

### T7.2 — Judge 통합 학습 [requires: T7.1]
- judge 점수 → reward (DPO 또는 가중 cross-entropy)
- 일일 호출 cap
- **AC**: judge 평균 점수 ≥7

### T7.3 — Cost 제어 [requires: T7.2]
- 모호 페어만 judge 송부 (cycle/pixel 점수 0.4~0.85 구간)
- 캐싱
- **AC**: 일일 LLM 호출 비용 측정, 예산 내

---

## Phase 8 — Loop D (Active learning)

### T8.1 — Confidence Calibration 점검 [blocks: T8.2]
- requirements.md Requirement 13 ECE ≤ 0.10
- temperature scaling fit
- **AC**: gold eval에서 ECE ≤ 0.10

### T8.2 — Uncertainty Sampler [requires: T8.1]
- top-1 < 0.55 또는 entropy > τ 인 입력 추출
- active queue 라우팅
- **AC**: low-confidence 비율 측정 + queue 동작

### T8.3 — Active Training Loop [requires: T8.2]
- 어려운 케이스를 epoch 우선순위 학습 데이터로
- **AC**: low-confidence 케이스 처리율 ≥60%

---

## Phase 9 — Runtime Integration

### T9.1 — Inference Wrapper (V2 fall-through) [blocks: T9.2]
- design.md §5 inference path 구현
- V2 시도 → 실패 시 ML → cycle 검증 → 결과 또는 V2 fallback
- **AC**:
  - `requirements.md` Requirement 8 모든 분기 케이스 테스트
  - 결정성 보장

### T9.2 — Self-Consistency Gate [requires: T9.1]
- requirements.md Requirement 9: runtime cycle 검증
- threshold 미달 → V2 fallback
- **AC**: 환각 (없는 컨테이너 생성) → 게이트 차단 시나리오 테스트

### T9.3 — `real-user` 셋 수집 (100~500)
- 실제 사용자 입력 + 수동 라벨
- 학습 데이터와 시간적 분리 (seal)
- **AC**: 100개 라벨 완료, leak 없음 검증

### T9.4 — `real-user` 평가 [requires: T9.3]
- 합격선: V2 단독 대비 +20pp 이상 개선
- **AC**: 합격 또는 미달 분석 문서

---

## Phase 10 — Public API / Packaging

### T10.1 — wasm 빌드 [blocks: T10.2]
- ONNX export → onnxruntime-web 또는 자체 wasm
- 200ms / 50줄 budget 검증
- **AC**:
  - 50줄 wireframe inference < 200ms (브라우저)
  - 500줄 < 1500ms

### T10.2 — npm 패키지 분리 [requires: T10.1]
- `@wyreframe/ml-parser` 옵션 의존성
- 모델 weights는 lazy download 가능
- **AC**:
  - 기본 패키지 설치 후 ml-parser 없어도 V2 동작
  - opt-in 시 import 가능

### T10.3 — Unified API [requires: T9.1, T10.2]
- `wyreframe/parse` export: V2 + ML fall-through 통합
- TypeScript 타입 (confidence schema 포함, requirements Req 3 Req 15)
- **AC**: TS 타입 체크 + 외부 consumer 시뮬레이션 통과

### T10.4 — Telemetry & 자동 수집 (opt-in)
- 어려운 입력 자동 수집 (사용자 동의 후) → 다음 학습 라운드 데이터
- 익명화
- **AC**: opt-out 기본, opt-in 시 동작

### T10.5 — 문서 & 마이그레이션 가이드
- `docs/ml-parser.md` 작성
- API 사용 예시, fallback 동작 설명, 모델 weights 라이선스
- **AC**: lint + 코드 샘플 실행 가능

---

## Acceptance Gate per Phase

- **P0**: V2 Renderer/Printer/Verifier 완료 + conformance + gold eval skeleton
- **P1**: 1k 합격 페어, multi-vote 수렴율 ≥40%, gate 통과율 ≥30%
- **P2**: 합성 셋 1k 가능, 라벨 100% 정확, 비중 캡 동작
- **P3**: Model A `clean-v2` ≥95%, 결정성 + 양자화 OK
- **P4**: Model B `clean-v2` ≥90%, ≤5M 파라미터
- **P5**: 50k 페어 누적, `llm-broken` ≥70%
- **P6**: cycle 통합 시 +5pp 이상 또는 미달 분석
- **P7**: judge 평균 ≥7, 비용 통제
- **P8**: ECE ≤0.10, low-confidence 처리율 ≥60%
- **P9**: `real-user` +20pp 이상
- **P10**: wasm <200ms / 50줄, npm import 동작

---

## Risk Log

| 리스크 | 영향 | 완화 |
| --- | --- | --- |
| LLM 교사의 체계적 편향 | 모델이 같은 편향 학습 | 다중 모델 cross-audit (T1.5), augmentation 비중 ≥30% |
| Model A 학습 비용 / 시간 | Phase 3 지연 | Model B를 병행 진행, fallback 확보 |
| Confidence calibration 실패 | requirements Req 13 미충족 | Phase 8 temperature scaling 사전 준비, 학습 중 ECE 모니터링 |
| wasm 추론 < 200ms 미달 | requirements Req 11 미충족 | Model B (작은 모델) 우선, ONNX runtime 최적화 |
| `real-user` 셋 부족 | Phase 9 평가 불가 | 초기부터 옵트인 텔레메트리 (사용자 동의) 또는 사내 사용 데이터로 시드 |
| 도메인 등록 회귀 | requirements Req 4 위반 | 코드 리뷰 체크리스트 + PR 템플릿에 "no domain registry" 체크박스 |
| LLM judge 비용 폭주 | budget 초과 | 일일 cap (T7.3), 모호 페어만 송부 |
| 합성/실데이터 분포 갭 | 실사용 성능 저하 | `real-user` seal + 매 deploy시 절대 회귀 금지 |

---

## Out of Scope (본 문서 기준)

- 자연어 → 와이어프레임 변환 (별도 후속 RFC).
- 이미지 → 와이어프레임 (별도 멀티모달 RFC).
- 모델 weights의 공개/공유 정책 (legal/license 별도 검토).
- 사용자 텔레메트리의 정책 (privacy / consent 별도 검토).
- V2 syntax 자체 변경 (`syntax-v2-parser` 영역).
- 인터랙션 DSL.
- 실시간 학습 (online learning) — checkpoint-based deploy까지만.
