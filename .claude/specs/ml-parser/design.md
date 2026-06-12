# ML-Based Wireframe Parser — Design

## Document Information

- **Version**: 0.2.0 (Draft)
- **Created**: 2026-06-12
- **Status**: Draft / RFC
- **Relation to V2 Parser**: Complementary — V2 remains the deterministic core; the ML parser is a *robustness layer* targeting inputs that V2 (and humans) can interpret but heuristics cannot recover.
- **Companion docs**:
  - `requirements.md` — formal acceptance criteria for the parser's behavior, identity guarantees, and public API
  - `tasks.md` — phased implementation tasks with dependencies
  - `self-improvement.md` — training loop architecture (data pipeline, four feedback loops, gold eval)
- **Cross-spec dependencies**: `syntax-v2-parser`, `v2-renderer`, `v2-ascii-printer`, plus the verifier infrastructure at `src/verifier/`.

---

## 1. Problem Statement

V2 파서는 strict 문법 기반의 휴리스틱 파서다. 정합한 입력에 대해서는 매우 강건하지만, 다음과 같은 입력에서 깨지거나 의미 손실이 발생한다:

- 미세한 정렬 어긋남 (1~2칸 어긋난 border)
- 일관성 없는 너비/높이 (사람이 "대략 맞췄다고 본" 것)
- LLM이 생성한 ASCII (자릿수 계산이 종종 틀림)
- 손으로 빠르게 그린 와이어프레임 (간격, 인덴트 흔들림)
- 누락된 닫힘 (`+`, `-`, `|` 한두 개 빠짐)
- 혼합 표기 (의도된 표기와 비공식 표기의 혼재)

핵심 관찰: **사람은 이런 입력을 거의 항상 정확하게 해석한다.** 즉 정답은 통계적으로 존재하며, 학습 가능한 신호다. V2의 recovery 로직을 케이스별로 늘리는 것은 한계가 명확하다 — 패턴이 본질적으로 long-tail 이다.

**목표**: "사람이 보면 알아볼 수 있는" 정도의 깨진 ASCII 와이어프레임을 입력받아, V2 파서가 산출하는 것과 동일한 형태의 AST(또는 그에 준하는 구조화된 출력)를 산출하는 ML 파서를 구축한다.

### 1.1 핵심 정체성: Lossy by Design

와이어프레임 → HTML 은 **본질적으로 정보 손실 변환**이다. 픽셀-퍼펙트 위치 보존이 목적이라면 도구 선택이 잘못된 것이고(Figma 등이 옳다), 와이어프레임은 정의상 *대략의 의도*만 표현한다. 본 파서는 이 손실을 회피하지 않고 적극 수용한다:

- **Semantic-first**: 출력 AST는 `{align: 'center', layout: 'row'}` 같은 카테고리화된 의미를 담는다. "column 12–19에 위치" 같은 픽셀 좌표는 진실의 원천이 아니라 신호일 뿐이다.
- **No explicit overrides**: 사용자가 다른 해석을 원하면 syntax에 새 마커를 추가하는 게 아니라 *와이어프레임 자체를 수정*한다 — 박스를 끝쪽으로 더 밀거나, 형제를 추가하거나, 컨테이너 너비를 좁혀서 의도를 명확하게 만든다. ASCII 그 자체가 유일한 입력 채널.
- **Ambiguity as first-class output**: 모호한 입력에 대해 단일 해석을 강요하지 않고 카테고리별 신뢰도 분포를 그대로 노출한다. 단일 해석이 필요한 다운스트림(렌더러/에디터)이 정책을 정한다.
- **LLM 분포에 정합**: ML 학습 corpus는 합성 데이터가 아니라 *LLM이 실제로 그리는 깨진 ASCII*에서 우선 수집된다 — 우리가 풀어야 할 분포는 그것이기 때문.

**비목표**:
- V2 파서를 대체하지 않는다. V2가 성공하면 그 결과를 신뢰한다.
- 런타임에 LLM을 호출하지 않는다. LLM은 학습 데이터 생성용 *교사* 역할만 한다.
- **배포 모델 자체가 LLM이 아니다**. 사전학습 언어 모델(ByT5/GPT-class/Llama 등)을 베이스로 fine-tune하지 않는다. 학생은 처음부터 학습한 작은 task-specific 신경망이다 (§4.2).
- 임의의 자연어를 와이어프레임으로 변환하지 않는다 (이건 별개의 과제).
- 명시적 정렬/위치 override syntax를 도입하지 않는다 (§11 참조).

---

## 2. High-Level Approach

LLM teacher (라벨 생성) → 작은 task-specific 학생 모델 (LM 베이스 없이 처음부터 학습) 패턴.

```
[1] Data generation (offline, LLM teacher)
    ├─ Scenario sampler (UI 도메인/디바이스/패턴 변주)
    ├─ Paired generator: scenario → (messy_ascii, target_ast)
    ├─ Quality gate: multi-vote consistency + reverse render
    └─ Augmentation: deterministic noise injection on canonical ASCII
                ↓
[2] Training (offline, no pretrained LM)
    └─ §4.2 후보 A (grid encoder + tree decoder) 또는
       §4.3 후보 B (sequence tagging + CRF) — 처음부터 학습
                ↓
[3] Inference (online, no LLM, no LM weights)
    ├─ V2 파서 시도
    ├─ V2 실패 / containsErrorRecovery=true → ML 파서 보조
    └─ Confidence threshold 미만이면 원래 V2 에러 반환
```

핵심 설계 원칙:

1. **AST가 진실의 원천**: ASCII는 가변, AST/HTML 구조는 결정적. 학습은 (ASCII → AST) 방향으로만.
2. **렌더러는 검증기**: 임의의 AST → ASCII 렌더가 가능하므로, 모델 출력의 self-consistency 검증이 무료로 가능하다.
3. **결정적 런타임**: 배포 모델은 작고 빠르고 오프라인. LLM dependency는 학습 시점에만.
4. **V2와 공존**: 두 파서를 fall-through 체인으로 운용. ML은 V2가 못 푸는 입력만 처리.

---

## 3. Data Generation Pipeline

**핵심 원칙**: 우리가 풀어야 할 분포는 *LLM과 사람이 실제로 그리는 깨진 ASCII*다. 합성 데이터를 깔끔하게 만들어서 거기에 노이즈를 주입하는 방식은 본질적 분포 갭을 만든다. 따라서:

```
   ┌───────────────────────────────┐
   │ Primary (≥ 50% of train set)  │   LLM-native ASCII corpus
   │  실제 LLM/사용자 출력 수집    │   →  강한 LLM/사람이 AST 라벨링
   └───────────────────────────────┘
                  │
                  ▼
   ┌───────────────────────────────┐
   │ Auxiliary (≤ 50%)             │   Synthetic + deterministic noise
   │ V1 렌더러 → 결정적 perturb    │   (long-tail / 깊은 중첩 보충)
   └───────────────────────────────┘
                  │
                  ▼
            merged training set
```

### 3.1 LLM-native ASCII Corpus (primary)

다양한 LLM에게 단순히 "이러이러한 UI를 ASCII 와이어프레임으로 그려달라"고만 요청해 *있는 그대로* 출력을 수집한다. AST를 같이 요구하지 않는다 — LLM이 ASCII와 AST를 동시에 일관되게 내는 게 어려우면 ASCII만 받는 게 더 자연스러운 분포를 만든다.

- **모델 다양성**: GPT-class, Claude-class, Gemini, 오픈웨이트(Llama / Qwen / DeepSeek 등) 최소 4종.
- **프롬프트 변주**: zero-shot / few-shot / "스타일 흉내" / chain-of-thought / "그냥 슥슥 그려" 톤.
- **시나리오 변주**: §3.4의 메타 샘플러로 도메인/디바이스/복잡도/패턴 cartesian product.
- **출력 보존**: 정렬 어긋남, 박스 깨짐, 표기 혼합, 너비 불일치 — 모두 그대로 저장. *이게 학습 신호의 본체다*.
- **사람 입력 corpus**: 가능하면 실제 사용자/디자이너가 손으로 그린 ASCII 와이어프레임도 별도로 모아 same pool에 편입.

### 3.2 라벨링 파이프라인

수집된 ASCII에 정답 AST를 부여하는 단계.

1. **1차 — Strong-LLM 다수결**: 가장 강한 LLM(GPT-4-class / Claude-Opus-class)에게 "이 ASCII를 의미적으로 해석해 V2 schema의 AST로 변환해줘" N=3~5회 호출. AST가 의미적으로 동일하게 수렴하면 채택.
2. **2차 — Cross-model audit**: 다른 계열 LLM이 그 라벨에 동의하는지 yes/no 판정. 불일치 항목은 다음 단계로.
3. **3차 — Round-trip self-consistency**: 라벨된 AST를 V1 렌더러로 다시 ASCII로 그려서 입력과 구조 시그니처(컨테이너 개수/깊이/자식 분포) 유사도 검증. 임계치 미달이면 폐기 또는 사람 검토 큐.
4. **4차 — Human-in-the-loop**: 어려운 라벨(다수결 불일치 + audit 부정)만 사람 라벨러가 결정. 학습 진행에 따라 모델이 잘 못 푸는 패턴이 자동으로 사람 큐로 라우팅 (active learning).

라벨 비용 절감을 위해 *입력의 모호함이 적은 항목*을 우선 라벨링하고, 모호한 항목은 라벨에 신뢰도 분포 자체를 정답으로 사용 (§4의 categorical output과 연결).

### 3.3 합성 데이터 (auxiliary)

LLM corpus가 못 채우는 long-tail edge case 보충용:

- 정합한 wyreframe 입력을 V2 파서로 AST 추출 → V1 렌더러로 완벽한 ASCII → 결정적 노이즈 주입.
- 라벨 100% 정확 (AST가 출발점이므로).
- 특히 *깊은 중첩*, *큰 와이어프레임*, *드문 컴포넌트 조합*처럼 LLM이 잘 안 만드는 영역 보강.

| 노이즈 종류 | 구현 |
| --- | --- |
| 1-칸 border 어긋남 | 특정 행의 `|`를 한 칸 이동 |
| Corner 누락 | `+`를 ` `로 치환 |
| 잘못된 들여쓰기 | 자식 컨테이너 indent ±1~2 |
| 트레일링 공백 / CRLF 혼합 | EOL 변주 |
| Width inconsistency | 같은 열에 위치해야 할 `|`를 ±1 이동 |
| Label typo | 컨테이너 안 텍스트에 character swap |

합성 데이터가 학습 셋의 50%를 넘지 않도록 비중 캡을 둔다 — 분포 우선순위가 흐려지면 LLM-native 입력에서 성능이 떨어진다.

### 3.4 시나리오 메타 샘플러

LLM에게 "어떤 UI를 그릴지" 다양성을 강제하기 위한 메타 변수 공간:

| 축 | 예시 값 |
| --- | --- |
| 도메인 | 로그인, 대시보드, 캘린더, 결제, 설정, 검색, 채팅, 프로필, … |
| 디바이스 | mobile / tablet / desktop |
| 복잡도 | 1~3 컨테이너 / 4~8 / 9~20 / 깊은 중첩 |
| 패턴 | 모달, 사이드바, 그리드, 카드 리스트, 폼, 탭, … |
| 표기 변주 | hyphenated ID 사용/미사용, emoji shortcode 유무, etc. |

이 축들을 cartesian product 후 샘플링하여 LLM 프롬프트에 주입. **분포 다양성은 메타 샘플러가 책임지고, LLM은 그 안에서 자연스럽게 (깨짐 포함) 그린다**.

> Note: "깨짐 정도"는 더 이상 샘플링 축이 아니다 — LLM이 자연스럽게 만들어내는 깨짐 정도 그 자체가 풀어야 할 분포이므로 인위적 조절을 하지 않는다. 부족하면 §3.3 합성 데이터가 보충.

### 3.5 데이터셋 규모 목표 (예비)

| 단계 | 페어 수 | LLM-native 비중 | 용도 |
| --- | --- | --- | --- |
| Smoke | 1k | 100% | 파이프라인 검증, overfit 가능 여부 확인 |
| MVP | 50k | ≥ 60% | 첫 평가 가능한 모델 |
| Production | 500k~1M | ≥ 50% | 안정적 일반화 |
| Real-user fine-tune | 200~2k | 100% (real user) | 실제 사용자 입력 + 라벨링 (hold-out + fine-tune) |

---

## 4. Model Architecture

### 4.1 출력 스키마 (Output Schema)

§1.1의 정체성에 따라, 출력은 *카테고리화된 의미 + 신뢰도 분포*다. float 좌표/너비를 그대로 회귀하지 않는다.

핵심 vocabulary (초안):

| 속성 | 카테고리 |
| --- | --- |
| `align` (가로) | `start` / `center` / `end` / `space-between` / `space-around` / `space-evenly` |
| `align` (세로) | `top` / `middle` / `bottom` / `stretch` |
| `layout` | `row` / `column` / `grid` / `stack` |
| `sizing` | `auto` / `fixed` / `flex(N)` / `fill` |
| `kind` | `container` / `text` / `button` / `input` / `select` / `checkbox` / `radio` / `divider` / `link` |
| `surface` | `inline` / `modal` / `overlay` / `drawer` / `popover` |

모델은 각 노드별로 위 속성들에 대해 **softmax 분포**를 출력한다. 예:

```json
{
  "kind":  { "container": 0.97, "text": 0.02, ... },
  "align": { "center": 0.62, "start": 0.31, "end": 0.04, ... },
  "layout":{ "row": 0.91, "column": 0.07, ... }
}
```

다운스트림 소비자는 보통 argmax를 쓰지만, 신뢰도가 낮으면 (e.g. top-1 < 0.55) 모호함 자체를 노출하거나 사람에게 묻는 정책을 적용할 수 있다.

**Fallback for true positional intent**: 카테고리들로 도저히 설명이 안 되는 입력(예: 단일 자식이 명백히 컨테이너의 27% 지점에 고정되어야 함)에 대해서만 `abs(percent)` 같은 escape를 출력. 학습 데이터에서도 이건 *드문 케이스*로 처리되어야 하며, 모델이 남용하면 정체성과 충돌.

**Tree structure는 별도**: AST의 노드 트리 자체는 sequence/tree decoder가 생성하고, 위 카테고리들은 각 노드의 "라벨"로 부착된다.

### 4.2 모델 후보 — 정체성 제약

§1.1의 정체성에 따라 **배포되는 모델은 LLM이 아니다**. LLM은 학습 데이터 생성용 *교사*로만 등장하며(§3), 런타임 추론에는 절대 호출되지 않는다. 배포 산출물은 *작은, 처음부터 학습한, task-specific 신경망*이다. 따라서 후보 아키텍처는 모두 다음 조건을 만족한다:

- 사전학습된 언어 모델(ByT5, GPT-class, Llama 등)을 *베이스*로 쓰지 않는다.
- 단일 와이어프레임 추론이 결정적이고 빠르다 (브라우저/노드 wasm 추론 기준 < 100ms 목표).
- 양자화/증류 후 모바일/엣지 배포 가능 크기 (수십 MB 이하 목표).

### 4.3 후보 A: Grid encoder + tree decoder (권장 1순위)

- **인코더**: ASCII를 (rows × cols) 2D 그리드 입력. 각 셀의 문자 임베딩 → axial transformer 또는 작은 CNN backbone (e.g. ConvNeXt-tiny 규모).
- **디코더**: V2 AST를 깊이 우선 순회 순서로 토큰화하여 autoregressive 생성. 각 노드 위치에서 §4.1 카테고리들의 softmax 분포 동시 출력.
- **장점**: 2D 정렬 신호(같은 열의 `|`가 정렬되어야 한다 등)가 인코딩 단계에 자연스럽게 들어감. V2 휴리스틱의 "wall alignment" 직관과 일치.
- **단점**: 구현 복잡 (2D positional encoding, axial attention 튜닝). 트리 디코더 학습 안정화 필요.
- **규모 목표**: 10~50M 파라미터.

### 4.4 후보 B: Sequence tagging (BiLSTM-CRF / 작은 transformer)

- **모델**: 각 (row, col) 셀을 토큰으로 보고 시퀀스 태그 예측. `border-h / border-v / corner / interior / text / button-bracket / ...` 같은 토큰 vocabulary.
- **상위 레이어**: CRF 또는 transition matrix가 *구조적 제약*("벽은 닫혀야", "코너는 4개 모여 사각형") 을 인코딩.
- **후처리**: 태그 시퀀스를 결정적 규칙으로 AST로 조립 (V2 휴리스틱의 일부를 재활용).
- **장점**: 모델이 작음 (1~5M 파라미터 가능). 학습 안정. 추론이 거의 결정적. wasm 추론 최적.
- **단점**: AST 트리 구조가 후처리 단계로 분리되어 end-to-end 학습 신호가 약함. 복잡한 중첩에서 후처리 규칙이 발목 잡힐 수 있음.

### 4.5 후보 C: Neurosymbolic — V2 파서 임계값을 학습 파라미터로

- **방법**: V2 휴리스틱의 임계값(허용 정렬 오차, recovery 우선순위, distribution 판별 cut-off 등)을 *학습 가능한* 실수 파라미터로 재구성. 미분 가능한 soft-relaxation을 통해 (ascii, ast) 페어로 fine-tune.
- **장점**: 코드 변화 최소. V2 파서의 정확성과 결정성을 그대로 상속하면서 *long-tail 케이스의 임계값만* 데이터로 보정. 모델 사이즈가 거의 0 (수백~수천 파라미터).
- **단점**: V2가 *애초에 시도조차 못 한* 깨진 입력에는 무력. 휴리스틱 구조 자체의 limitation을 넘지 못함. 가장 보수적 옵션.
- **위상**: A/B의 backup 또는 hybrid 구성요소로 (V2 우선 → ML B 후보 → ML A 후보 fallback chain).

### 4.6 결정 기준

MVP에서 **A와 B를 병행 학습**, 동일 평가셋(`design.md §6.2` 메트릭)에서 비교:

- B가 `clean-v2` + `synthetic-broken` 셋에서 충분한 성능을 내고 추론 비용이 압도적으로 낮다면 **B 채택**.
- B가 깊은 중첩/모호 정렬에서 무너지고 A가 뚜렷이 이긴다면 **A 채택**.
- 둘 다 부족하면 C를 baseline anchor로 두고 A의 학습 데이터를 더 부어 본다.

C는 별도 trace로 항상 enable 가능한 *공짜 회복* 경로 — V2 파서가 이미 있으므로 추가 비용 거의 0.

---

## 5. Inference Path

V2와 ML을 어떻게 조합할지가 사용자 경험을 결정한다.

```
parse(input):
    v2_result = V2.parse(input)

    if v2_result.errors.isEmpty:
        return v2_result    # 빠른 경로, 결정적

    ml_result = ML.parse(input)
    ml_confidence = ML.confidence(ml_result)

    if ml_confidence < THRESHOLD:
        return v2_result    # ML도 자신 없으면 V2 에러 그대로

    # ML 결과 검증: AST → 렌더 → 입력과 구조 비교
    rendered = render(ml_result.ast)
    if structural_similarity(rendered, input) < SIM_THRESHOLD:
        return v2_result    # self-consistency 실패

    return {
        ast: ml_result.ast,
        source: "ml",
        warnings: v2_result.errors.map(toWarning),
        confidence: ml_confidence
    }
```

핵심:
- V2가 성공하면 ML 호출 자체가 없음 (성능 보장).
- ML 결과는 항상 **self-consistency 검증** 후 반환 (잘못된 환각 방지).
- 사용자에게는 "원본 입력에 이런 모호한 점이 있었는데, 이렇게 해석했습니다" 형태로 표시 가능.

---

## 6. Evaluation

### 6.1 평가셋 구성

| 셋 | 출처 | 크기 (예비) | 용도 |
| --- | --- | --- | --- |
| `clean-v2` | V2 정합 입력 (기존 V2 테스트) | 200 | 회귀 방지 (ML이 V2와 동일하게 풀어야) |
| `synthetic-broken` | 합성 노이즈 hold-out | 1k | 일반화 |
| `llm-broken` | LLM 합성 데이터 hold-out | 1k | 분포 내 일반화 |
| `real-user` | 실제 사용자 입력 + 수동 라벨 | 100~500 | 진짜 평가 |

### 6.2 메트릭

- **Exact AST match**: 트리 구조 + 노드 속성 완전 일치율.
- **Structural F1**: 컨테이너 개수, 부모-자식 관계 precision/recall.
- **Label accuracy**: 텍스트 라벨 일치율 (편집 거리 기반).
- **Self-consistency rate**: render(ml_ast) ↔ input 구조 유사도 분포.
- **V2 regression**: `clean-v2` 셋에서 ML이 V2와 일치하는 비율 (≥99% 목표).

### 6.3 베이스라인

- V2 자체 (정의상 `clean-v2` 100%, broken 셋들에서 ?% — 이 갭이 ML이 메워야 할 영역).
- LLM zero-shot (참고용 상한선, 런타임 사용 불가).

---

## 7. Risks & Mitigations

| 리스크 | 영향 | 완화 |
| --- | --- | --- |
| LLM 교사의 체계적 편향 | 모델이 같은 편향 학습 | 다중 모델 cross-audit, 결정적 augmentation 비중 ≥30% |
| 깨진 ASCII에 대한 모호성 (정답이 둘 이상) | 평가 노이즈 | 평가 시 top-k 일치 허용, real-user 셋은 다중 라벨러 |
| 모델 환각 (없는 컨테이너 생성) | 사용자 신뢰 손상 | self-consistency 게이트 + confidence threshold + V2 fallback |
| 추론 비용 | 브라우저/노드 부담 | <1B 모델, ONNX/wasm 양자화, V2가 처리하는 케이스는 ML 미호출 |
| 데이터 누수 | 평가셋 오염 | hold-out은 시나리오 시드 단위로 분리, real-user 셋은 합성 데이터와 시간적 분리 |
| 분포 갭 (synthetic ≠ real) | 실사용에서 성능 저하 | real-user 셋 fine-tune 단계 필수화, 사용 중 수집된 입력으로 주기적 재학습 |

---

## 8. Open Questions

1. **AST 직렬화 형식**: JSON, S-expression, custom token vocab 중 학습 효율이 가장 좋은 것은?
2. **컨테이너 ID 일관성**: ML이 생성한 ID가 입력의 ID와 정확히 같아야 하는가, 의미만 보존하면 되는가?
3. **부분 결과**: 입력의 일부만 해석 가능할 때, ML이 "여기까지는 안다" 형태로 부분 AST를 내야 하는가?
4. **온디바이스 비용 허용치**: 브라우저에서 100ms / 500ms / 2s 중 어디까지 허용 가능한가?
5. **V2 vs ML 충돌 시 정책**: V2가 `containsErrorRecovery=true`로 부분 성공하고 ML도 자신 있을 때, 어느 쪽을 채택하는가?
6. **사용자에게 보이는 표현**: ML이 해석한 결과를 "추측"으로 표시할지, "정상 파싱"과 동일하게 표시할지.
7. **합성 데이터의 저작권/라이선스**: LLM 출력으로 만든 데이터셋 공개 시 라이선스 정책.

---

## 9. Out of Scope (현재 문서 기준)

- 자연어 → 와이어프레임 (e.g., "로그인 화면 그려줘" → ASCII).
- 와이어프레임 → 실제 HTML/Tailwind 코드 생성 (별도 layer; AST → HTML 은 기존 렌더 layer가 담당).
- 이미지(스크린샷, 손그림) → 와이어프레임.
- 실시간 학습 / online learning.
- Multi-modal (텍스트 + 이미지) 입력.
- **명시적 정렬/위치 override syntax** (e.g. `[@30%Btn]`, `align=center` 주석 등). §1.1의 정체성에 따라 ASCII 자체가 유일한 입력 채널이며, 사용자는 와이어프레임을 수정함으로써 의도를 명확히 한다. override 마커를 도입하는 순간 (a) LLM-native 입력에는 존재하지 않아 무용지물이 되고, (b) syntax가 지저분해지며, (c) ML 모델이 풀어야 할 모호함을 회피하는 escape hatch가 된다.

이 항목들은 본 ML 파서가 자리잡은 후 후속 RFC에서 다룬다.
