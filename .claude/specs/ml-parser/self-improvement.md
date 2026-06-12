# ML Parser — Self-Improvement Loop

## Document Information

- **Version**: 0.1.0 (Exploratory)
- **Created**: 2026-06-12
- **Status**: Draft / RFC
- **Companion to**: `design.md` (architecture/output schema), `requirements.md` (목표/범위), `v2-renderer/*` (AST→HTML), `v2-ascii-printer/*` (AST→ASCII)
- **Scope**: 본 문서는 ML 파서가 *어떻게 자기 스스로 학습/개선되는지*의 파이프라인을 정의한다. 모델 구조나 출력 형식은 `design.md`를 참조.

---

## 1. Introduction

### 1.1 왜 자가 개선이 가능한가

ML 파서는 본질적으로 *"라벨이 비싼"* 문제로 보이지만, `design.md` §1.1이 박은 두 원칙이 합쳐지면 라벨이 사실상 무료가 된다:

1. **Lossy by design** — 출력은 시각 카테고리. 단일 픽셀 정답이 필요 없음.
2. **No domain registry** — 시스템은 도메인 의미를 부여하지 않으므로, *"맞는 출력"의 정의가 외부 지식에 의존하지 않는다*.

이 두 조건이 만나면 **출력의 정답성은 입력 그 자체에 비추어 검증 가능**해진다:

> *HTML이 ASCII처럼 보이면 맞는 매핑이다.*

라벨러가 필요 없다. 모델 자신의 출력이 입력에 의해 채점된다. 이게 self-supervision의 황금 조건이고, 본 문서가 정의하는 모든 루프의 기반이다.

### 1.2 세 가지 prerequisite 컴포넌트

self-improvement 인프라는 다음 세 결정적 컴포넌트 위에 작동한다. ML 모델은 이 셋 사이에서 움직이며, 자신만 비결정적이고 나머지는 모두 결정적:

| 컴포넌트 | 방향 | 역할 in loop | 스펙 |
| --- | --- | --- | --- |
| **V2 Parser** | ASCII → AST | 깨끗한 입력에 대한 *무료 정답* 생성기. ML이 따라야 할 anchor. | `syntax-v2-parser/` |
| **V2 Renderer** | AST → HTML | pixel-comparison 분기를 위한 forward 렌더링 (브라우저 스크린샷 대상). | `v2-renderer/` |
| **V2 ASCII Printer** | AST → ASCII | cycle-consistency 분기를 위한 역방향 인쇄 (A vs A' 직접 비교). | `v2-ascii-printer/` |

ML 파서는 이 셋 사이에서 V2 Parser가 못 푸는 입력만 다루고, 결과를 다른 두 컴포넌트로 검증받는다.

> **중요**: 이전 draft에서 "V1 렌더러"로 표기했던 *AST→ASCII 역방향 컴포넌트는 코드베이스에 존재하지 않았다*. 그 역할을 새 spec인 `v2-ascii-printer`가 맡는다. 기존 `src/renderer/Renderer.res` (V1 forward 렌더러)는 본 loop에서 사용하지 않는다.

---

## 2. The Self-Verification Principle

### 2.1 검증의 세 축

모델 출력의 정답성은 다음 세 가지 독립적 신호로 측정된다. 어느 하나에만 의존하지 않고 *가중 평균 + 분기 신호*로 사용한다.

```
                       ASCII A
                          │
                          ▼
                  ┌──[ML Model]──┐
                  │              │
                  ▼              ▼
                V2 AST       (confidence
                  │           distribution)
                  │
       ┌──────────┼─────────────────────────┐
       ▼          ▼                         ▼
 ┌──────────┐ ┌──────────────┐        ┌────────────┐
 │V2 Renderer│ │V2 ASCII      │        │LLM Judge   │
 │ AST→HTML │ │Printer AST→A'│        │"AST ≈ A?"  │
 └─────┬────┘ └──────┬───────┘        └─────┬──────┘
       ▼             ▼                       ▼
  HTML screenshot  ASCII A'                Semantic
       │             │                     judgment
       ▼             ▼                       │
 [Pixel SSIM    [Cycle Edit Distance         │
  vs A image]    A vs A']                    │
       │             │                       │
       └──────┬──────┴────────┬──────────────┘
              ▼               ▼
        weighted score s ∈ [0, 1]
```

### 2.2 세 축의 역할 분담

- **Pixel SSIM**: "전체적인 시각 인상이 비슷한가". 빠르고 결정적. 라벨 텍스트의 정확성에는 둔감. **V2 Renderer**가 만든 HTML을 헤드리스 브라우저로 스크린샷.
- **Cycle Edit Distance**: "ASCII로 되돌렸을 때 구조가 같은가". 의미 보존을 직접 측정. **V2 ASCII Printer**의 결정성에 의존.
- **LLM Judge**: "사람이 봤을 때 같은 의도로 보이는가". 미묘한 의미 누락(라벨 오타, 정렬 카테고리 오류) 포착. 비용 큼.

각 축은 다른 종류의 실패를 잡는다. 어느 하나라도 강하게 fail하면 그 페어는 학습에서 제외된다.

---

## 3. Self-Improvement Loops

네 종류의 루프가 *동시에 또는 단계적으로* 가동된다. 각각이 다른 신호를 학습에 주입.

### 3.1 Loop A — Cycle Consistency

```
ASCII A ──[ML]──► V2 AST ──[V2 ASCII Printer]──► ASCII A'
                                                    │
                  A vs A' (edit distance / IoU) ◄───┘
                                  │
                                  ▼
                            loss / reward
```

- A → AST → A' 의 cycle을 닫고 A와 A'의 유사도를 신호로 사용.
- CycleGAN의 cycle consistency loss와 동형.
- V2 ASCII Printer가 결정적이라는 점이 핵심. 양방향 중 한쪽이 결정적이면 cycle을 닫을 수 있다.
- **주의**: cycle만으로는 *trivial한 항등 매핑*(아무것도 안 하기)으로 수렴 가능 → 항상 다른 루프와 결합 사용.

### 3.2 Loop B — Bootstrap Distillation (자기 증류)

```
M_0 (작은 합성 데이터로 시드)
  │
  ▼
LLM 무한 ASCII 배치 생성
  │
  ▼
M_n 이 HTML 추론  ──►  verifier 통과한 페어만 채택
  │
  ▼
M_{n+1} = train(M_n, 통과 페어들)
  │
  ▼
... 반복 ...
```

- 매 iteration에서 *모델 자신의 자신감 있고 검증된 출력*만 다음 학습 데이터로 사용.
- 강해질수록 통과율↑, 분포 cover 확대.
- 사람 라벨러 0명.
- **주의**: 모델 편향이 그대로 재학습되므로 다양성 보상과 LLM judge 배치로 견제 필요.

### 3.3 Loop C — LLM Judge in the Loop

```
(ASCII A, HTML H) 페어
  │
  ▼
강한 multimodal LLM 입력:
- A: 텍스트
- H: 헤드리스 브라우저 스크린샷
- prompt: "H가 A를 충실히 표현하는가? 0-10 점.
          구체적 불일치 지점 나열."
  │
  ▼
score + discrepancy list  ──►  학습 신호 (RLHF/DPO/GRPO 류)
```

- LLM이 *답을 만들지 않고 비교만* 하므로 hallucination 위험이 작다.
- visual verifier의 blind spot(라벨 텍스트 누락, 정렬 카테고리 오류, 곡률 정도) 보강.
- 비용 크므로 다음 두 가지에만 적용:
  - cycle/pixel 점수가 *애매한 중간 영역*인 페어 (확실히 좋거나 나쁜 건 LLM 안 거침)
  - active queue에서 올라온 어려운 케이스 (§3.4)

### 3.4 Loop D — Active Uncertainty Sampling

```
모델 출력 confidence 분포 모니터링
  │
  ▼
top-1 < 0.55  또는  entropy > τ  인 입력
  │
  ▼
"어려운 케이스" 큐
  │
  ▼
LLM Judge (또는 사람 라벨러)로 우선 송부
  │
  ▼
라벨된 어려운 케이스 = 다음 epoch의 high-priority 학습 데이터
```

- 모델이 *자기가 모르는 걸 안다*는 가정 (well-calibrated 가정 필요).
- 노력을 자동으로 어려운 분포 영역에 집중.
- 일반 active learning이지만, confidence가 §4.1의 카테고리 분포에서 자연스럽게 나옴.
- **주의**: 모델이 over-confident하면 (calibration 안 맞으면) 진짜 어려운 케이스가 큐에 안 올라옴 → 주기적 calibration 점검 필요.

### 3.5 루프들의 합성

네 루프는 *우선순위 + 비용 + 신호 종류*가 달라서 동시에 가동되어도 충돌하지 않는다. 권장 합성:

| 단계 | 활성 루프 | 이유 |
| --- | --- | --- |
| Bootstrap (M_0 ~ M_3) | B + A | 최대한 빠르게 데이터 확보, cycle은 신호 다각화 |
| Maturation (M_4 ~) | B + A + C | LLM judge로 미묘한 오류 잡기 시작 |
| Steady-state | B + A + C + D | 어려운 분포 영역 능동 탐색 |
| Long-term | B + A + C + D + real-user fine-tune | 분포 갭 봉합 |

---

## 4. Component Architecture

```
                ┌───────────────────────────────────┐
                │  [4.1] LLM ASCII Generator        │
                │  (도메인 메타 샘플러 + 다중 LLM)  │
                └────────────────┬──────────────────┘
                                 │
                                 ▼
                          [ASCII 배치]
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
   [4.0] V2 deterministic parser           [4.6] 현재 모델 M_n
              │                                     │
              ▼                                     ▼
       성공 → HTML 골든 (무료 정답)         HTML 추론 + confidence
              │                                     │
              └──────────────┬──────────────────────┘
                             ▼
                  ┌──────────────────────────┐
                  │ [4.3] Visual Verifier    │
                  │   - Pixel SSIM           │ ◄── [4.2a] V2 Renderer (HTML)
                  │   - Cycle Edit Dist      │ ◄── [4.2b] V2 ASCII Printer
                  └────────────┬─────────────┘
                               │
                       score ∈ [0, 1]
                               │
              ┌────────────────┼─────────────────┐
              ▼                ▼                 ▼
       high (≥ 0.85)   ambiguous (0.4–0.85)   low (< 0.4)
              │                │                 │
              │                ▼                 │
              │      ┌──────────────────┐        │
              │      │ [4.4] LLM Judge  │ (Loop C)│
              │      └────────┬─────────┘        │
              │               │                  │
              │     consensus score              │
              │               │                  │
              └───┬───────────┴──────────────────┘
                  ▼
        [4.5] Active Queue Manager
                  │
   ┌──────────────┼──────────────┐
   ▼              ▼              ▼
 학습 큐       복습 큐       폐기/디버그
   │                              ↑
   ▼                              │
[4.6] Training Orchestrator       │
   │                              │
   ▼                              │
M_{n+1}                           │
   │                              │
   ▼                              │
[4.7] Gold Eval Suite ────────────┘
   │
   ▼
deploy or rollback ──► (loop)
```

### 4.1 LLM ASCII Generator

- 다중 LLM (GPT, Claude, Gemini, 오픈웨이트) ASCII 생성 요청.
- 시나리오 메타 샘플러 (design.md §3.4 참조) 로 도메인/디바이스/복잡도/패턴 cartesian product.
- 같은 시나리오를 다양한 LLM에 보내 분포 다양성 확보.
- 출력 검증/정제 없음 — *깨진 그대로* 보존.

### 4.2a V2 Renderer (AST → HTML)

본 self-improvement loop의 **prerequisite** 중 하나. Pixel-comparison 분기 전용.

- 입력: V2 AST
- 출력: 결정적 HTML/DOM
- 같은 AST → 같은 HTML 문자열 (`v2-renderer/requirements.md` Requirement 11).
- 헤드리스 브라우저(Playwright/Puppeteer)로 스크린샷을 떠서 visual verifier가 ASCII 입력의 monospace 캔버스 렌더와 SSIM 비교.
- 전체 명세: `v2-renderer/{requirements,design,tasks}.md`

> **현 상태**: 미구현. `v2-renderer/tasks.md` Phase 1~10 진행 필요.

### 4.2b V2 ASCII Printer (AST → ASCII)

본 self-improvement loop의 **prerequisite** 중 하나. Cycle-consistency 분기 전용.

- 입력: V2 AST
- 출력: 결정적 ASCII 와이어프레임
- 같은 AST → 같은 ASCII (`v2-ascii-printer/requirements.md` Requirement 5).
- Round-trip 보장: `V2Parser.parse(V2Printer.print(ast))` 가 ast와 semantically equal (`v2-ascii-printer/requirements.md` Requirement 3).
- 이 cycle 보장이 self-improvement 루프 A의 수학적 기반.
- 전체 명세: `v2-ascii-printer/{requirements,design,tasks}.md`

> **현 상태**: 미구현 (이 컴포넌트는 코드베이스에 존재한 적이 없음). `v2-ascii-printer/tasks.md` Phase 1~10 진행 필요. 본 self-improvement loop의 가장 큰 prerequisite 작업.

### 4.3 Visual Verifier

세 가지 sub-metric을 결합:

1. **Pixel SSIM**:
   - ASCII → monospace 캔버스 이미지 (canvas/headless 렌더, 고정 폰트)
   - HTML → 헤드리스 브라우저 스크린샷 (Playwright/Puppeteer, viewport 고정)
   - SSIM(A_img, H_img) → 점수 ∈ [-1, 1] → [0, 1] 정규화

2. **Cycle Edit Distance**:
   - HTML → V1 Renderer → ASCII A'
   - Edit distance(A, A') / max(len(A), len(A'))
   - 1 - 정규화 거리 → 점수

3. **Region IoU** (선택):
   - A와 A' 각각에서 박스/원/텍스트 영역 검출
   - IoU 계산 (구조 유사성을 보강)

최종: `score = w₁·SSIM + w₂·CycleSim + w₃·IoU`, 초기 가중치는 (0.3, 0.5, 0.2) 권장. 학습 진행에 따라 튜닝.

### 4.4 LLM Judge

- 강한 multimodal LLM에 (ASCII text, HTML screenshot) 동시 제시.
- Prompt template:

```
다음은 ASCII 와이어프레임과 그것을 HTML/CSS로 매핑한 결과의 스크린샷이다.

ASCII:
{ascii_text}

HTML 스크린샷:
[이미지 첨부]

질문:
1. HTML이 ASCII의 시각 구조(박스 위치/중첩/정렬/곡률/장식)를 충실히 표현하는가? 0–10 점.
2. 구체적 불일치 지점을 나열하라. 형식: "- {위치}: {불일치 내용}".
3. 도메인 의미(예: '디지바이스'라서 LCD가 초록색이어야 한다)는 평가 기준이 아니다. 오직 ASCII 시각 어휘의 보존 여부만 본다.

JSON으로 답:
{"score": int, "discrepancies": [str, ...], "rationale": str}
```

- 결과:
  - `score` → 직접 학습 신호 (또는 보상)
  - `discrepancies` → 잘못된 부분에 대한 *위치 기반 fine-grained 신호* (가능하면 노드 단위 weighting)
  - `rationale` → 디버그/감사용

### 4.5 Active Queue Manager

큐 4종:
- **train**: 검증 통과, 다음 epoch에 추가
- **review**: ambiguous, LLM judge로 라우팅
- **hard**: confidence 낮은 입력, 우선순위 학습 데이터
- **trash**: 명백히 잘못된 출력, 디버그용 보관

규모 관리:
- train 큐는 epoch 단위로 소비
- hard 큐는 train 큐의 ≤ 20%로 cap (over-fitting 방지)
- review 큐는 일일 LLM 예산에 맞춰 drain

### 4.6 Training Orchestrator

- 매 N (예: 1k) 페어 누적마다 한 epoch.
- 학습은 *연속적*: 항상 직전 checkpoint에서 시작, 새 데이터 + reservoir sample.
- 학습 데이터 mix: bootstrap 80% + hard 15% + real-user 5% (real-user는 모이는 대로 항상 끼움).
- 학습 후 gold eval suite (§4.7) 통과 시에만 deploy.

### 4.7 Gold Eval Suite

학습이 *진짜로 좋아지고 있는지* 검증하는 변하지 않는 셋. self-improvement loop와 분리되어야 함 — 그렇지 않으면 측정과 최적화가 같은 신호가 되어 신뢰성 붕괴.

- `clean-v2` (~200): V2 정합 입력. ML이 V2와 일치하는지.
- `synthetic-broken` (~1k): 합성 노이즈 hold-out.
- `llm-broken` (~1k): LLM 합성 데이터 hold-out.
- `real-user` (~100–500): 실제 사용자 입력 + 수동 라벨.

매 deploy 후보 모델은 위 4셋 모두에서 *직전 production 대비 회귀 없음* 이 조건. 한 셋이라도 회귀 시 rollback.

---

## 5. Verification Metrics (요약 카드)

| 메트릭 | 무엇을 잡나 | 비용 | 신뢰도 |
| --- | --- | --- | --- |
| Pixel SSIM | 전체 시각 인상 | 낮음 | 중 (라벨엔 둔감) |
| Cycle Edit Distance | 구조 보존 | 낮음 | 중 (V1 렌더러 한계) |
| Region IoU | 영역 분할 | 중 | 중 |
| LLM Judge | 의미 보존 | 높음 | 높음 (모델 능력에 비례) |
| Human Audit | 모든 것 | 매우 높음 | 최고 |

전략: 저비용 메트릭은 *모든 페어*에, LLM judge는 *애매한 페어* 에만, 사람은 *gold eval 셋과 신규 패턴 검증*에만.

---

## 6. Failure Modes & Mitigations

| 함정 | 증상 | 완화 |
| --- | --- | --- |
| **Mode collapse** | 모델이 "안전한 출력"(예: 항상 nested div)만 생성해 verifier만 통과 | 다양성 보상, LLM judge가 "구별 가능성/표현력" 평가, 입력 다양성 메타 샘플러 강제 |
| **Verifier blind spot** | SSIM 통과하지만 라벨 텍스트 누락 등 의미 오류 | OCR 단계 텍스트 일치 별도 검증, LLM judge가 텍스트 누락 explicit check |
| **Local optimum** | 점수 정체, 진짜 능력 정체 | 주기적 cold-start 라벨 주입, hard 큐 비중 일시 상향, 다른 LLM judge로 교차 검증 |
| **Ambiguity 박제** | 모호 입력의 임의 해석이 정답으로 학습됨 | 신뢰도 낮은 페어는 학습에서 제외, active queue로만 라우팅 |
| **Distribution drift** | 합성 ASCII 분포가 실 사용자와 멀어짐 | real-user eval 셋 절대 변경 금지, 거기서 회귀 즉시 알람 |
| **Trivial cycle** | A → 빈 div 매핑 → A' 도 빈 box. cycle은 닫히나 무의미 | cycle만 단독 신호로 쓰지 않음, pixel SSIM과 LLM judge 가중 결합 |
| **Calibration drift** | 모델이 over-confident → active queue 비어버림 | 매 epoch 후 reliability diagram 점검, calibration loss 추가 |
| **Judge cost runaway** | LLM judge 호출이 무한 증가 | 일일 호출 cap, 가운데 신뢰도 페어만 judge 송부, judge 결과 캐싱 |
| **V2 Printer/Renderer 한계** | V2 Printer가 cover 못하는 시각 어휘는 cycle 검증 자체가 노이즈, V2 Renderer가 cover 못하면 pixel SSIM 분기 신뢰성 저하 | 두 컴포넌트가 V2 AST 15개 variant 100% cover하는지 Phase 0에서 conformance 테스트로 검증 |

---

## 7. Phased Rollout

### Phase 0 — Prerequisite (4~8주)

본 self-improvement loop가 가동되기 위한 결정적 컴포넌트들을 먼저 land. 본 phase는 ML 작업이 아니라 *deterministic 인프라* 구축.

- **V2 Renderer 구현**: `v2-renderer/tasks.md` Phase 1~10 완료. AST → HTML 결정적 출력 + 10k 노드 < 100ms.
- **V2 ASCII Printer 구현**: `v2-ascii-printer/tasks.md` Phase 1~10 완료. AST → ASCII 결정적 출력 + round-trip 100% + 10k 노드 < 100ms.
- **Conformance 테스트**: 두 컴포넌트가 V2 AST의 15개 variant를 모두 cover하는지 확인. 같은 corpus AST에 대해 양쪽 모두 정상 동작.
- **Visual verifier 구현**: Pixel SSIM (V2 Renderer 스크린샷 vs 입력 ASCII 캔버스 렌더) + Cycle Edit Distance (V2 Printer 결과와 입력 비교) + Region IoU.
- **Gold eval 셋 4종 초기화**: clean-v2, synthetic-broken, llm-broken 부트, real-user 시드.
- **합격선**:
  - 임의 V2 AST → V2 Printer ASCII → V2 Parser → 같은 V2 AST (round-trip 100%)
  - 임의 V2 AST → V2 Renderer HTML → V2 Renderer 재실행 → byte-identical HTML
  - Visual verifier가 (정답 ASCII, 정답 HTML) 페어에서 score ≥ 0.95

### Phase 1 — Bootstrap M_0 (2~3주)

- 합성 데이터 1k + Loop B(distillation) + Loop A(cycle)만 가동.
- 작은 모델 (ByT5-small 또는 Qwen-0.5B LoRA).
- 합격선: gold eval `clean-v2` ≥ 95%, `synthetic-broken` ≥ 70%.

### Phase 2 — Add LLM Judge (3~4주)

- Loop C 가동 (모호 페어만).
- LLM judge 일일 호출 cap (예: 1k/day).
- 합격선: `llm-broken` ≥ 75%, judge 평균 점수 ≥ 7.

### Phase 3 — Add Active Learning (4~6주)

- Loop D 가동.
- Calibration 점검 시스템.
- 합격선: 모호 케이스(top-1 < 0.55) 처리율 ≥ 60%.

### Phase 4 — Continuous Steady State (이후)

- 4 루프 모두 가동.
- 일일 checkpoint, 자동 회귀 감지, 자동 rollback.
- real-user 입력 자동 수집 → eval 셋 보강.
- 합격선: 30일 무인 운영, real-user eval 월간 +1pp 이상 개선.

---

## 8. Open Questions

1. **V1 렌더러 결정성 보장**: 폰트 metric, anti-aliasing, viewport — 어디까지 고정해야 cycle이 진짜 deterministic 한가?
2. **LLM Judge 모델 선택**: GPT-4o / Claude Opus / Gemini Pro 중 가장 *시각 와이어프레임 판별*에 강한 모델은? 벤치마크 필요.
3. **Confidence calibration**: §4.1 카테고리 분포가 well-calibrated 한지 어떻게 보장? Temperature scaling? Conformal prediction?
4. **Reservoir sample 정책**: 옛 데이터를 얼마나 오래 반복 학습에 포함시킬지. catastrophic forgetting 방지와 신선도의 trade-off.
5. **Gold eval 셋 오염**: self-improvement loop가 길어지면 eval 셋과 학습 셋이 의도치 않게 가까워질 수 있음. 격리 보장 메커니즘?
6. **Compute 예산**: 4 루프 동시 가동 시 GPU/API 비용 예상치. 비용 vs 개선 곡선 어디서 saturate?
7. **사람 audit 빈도**: 자동화가 충분해 보여도 주기적 인간 검토가 필요한가? 빈도/표본 크기?
8. **Cycle의 두 방향**: HTML → ASCII → HTML 의 *반대 방향* cycle도 학습에 유용한가? (V2 파서를 reverse training signal로)

---

## 9. Out of Scope (현재 문서 기준)

- 모델 아키텍처/하이퍼파라미터 (→ `design.md` §4).
- 출력 스키마/AST 정의 (→ `design.md` §4.1).
- V2 Renderer 명세 (→ `v2-renderer/{requirements,design,tasks}.md`).
- V2 ASCII Printer 명세 (→ `v2-ascii-printer/{requirements,design,tasks}.md`).
- LLM Judge의 fine-tuned 변형 (→ 후속 RFC).
- Online learning (서비스 중 실시간 가중치 업데이트). 본 문서는 *checkpoint-based deploy*까지만 다룬다.
- 적대적 입력에 대한 robustness (→ 후속 RFC).

---

## 10. Why This Works (요약)

이 self-improvement 시스템은 wyreframe 프로젝트의 **세 결정적 컴포넌트가 서로를 강화**하는 구조 위에 서 있다:

- **V2 Parser** (ASCII → AST) → 깨끗한 입력의 *무료 정답* 생성기, 학습 신호의 anchor.
- **V2 Renderer** (AST → HTML) → pixel-level 검증을 위한 시각 렌더링 기계.
- **V2 ASCII Printer** (AST → ASCII) → cycle을 닫는 *역방향 검증 기계*.

ML 파서는 이 셋 *사이*에서 V2 Parser가 못 푸는 long tail만 처리하고, 다른 두 컴포넌트로 *두 독립 채널*(pixel + cycle)로 검증받는다. 시간이 지날수록 ML이 cover하는 영역이 자동 확장된다.

그리고 이 구조는 *순수 시각 매핑 원칙* (design.md §1.1) 덕분에 가능하다 — 도메인 등록이 끼었다면 정답이 외부 지식에 의존했을 것이고, 자가 검증이 닫히지 않았을 것이다. **원칙의 순수성이 시스템의 자동성을 가능케 한 셈**이다.

```
              ┌─────────────────────────────────────────┐
              │              ML Parser (학습 대상)         │
              │   ASCII ──► V2 AST + confidence dist    │
              └────────────┬────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            │            ▼
      ┌──────────────┐     │     ┌──────────────┐
      │ V2 Parser    │     │     │ V2 ASCII     │
      │ (anchor)     │     │     │ Printer      │
      │ ASCII→AST    │     │     │ AST→ASCII'   │
      └──────────────┘     ▼     └──────────────┘
                    ┌──────────────┐
                    │ V2 Renderer  │
                    │ AST→HTML     │
                    └──────────────┘

   세 결정적 컴포넌트가 ML 파서를 *가운데 두고* 정답/검증을 공급한다.
```
