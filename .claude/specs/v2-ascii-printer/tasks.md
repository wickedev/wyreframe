# Wyreframe V2 ASCII Printer — Implementation Tasks

## Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Implements**: `requirements.md` + `design.md` in this directory
- **Style**: 각 task는 단일 PR 크기. `[requires:]` / `[blocks:]`로 의존성 명시.

---

## Phase Summary

| Phase | 목적 | Tasks | 합격선 |
| --- | --- | --- | --- |
| **P1 — Scaffolding** | 디렉터리, 타입, 더미 진입점 | T1.1 ~ T1.4 | `print()` 호출 시 빈 출력 반환 |
| **P2 — Canvas & Border** | 2D 캔버스 + 문자셋 | T2.1 ~ T2.3 | 박스 하나 그리기 byte-identical |
| **P3 — Width/Height Inference** | bottom-up 사이즈 계산 | T3.1 ~ T3.3 | 모든 leaf+container 사이즈 정확 |
| **P4 — Position Pass** | top-down 좌표 부여 | T4.1 ~ T4.4 | distribution/alignment 알고리즘 통과 |
| **P5 — Core Node Emitters** | Scene/Component/Container/Text | T5.1 ~ T5.5 | 4 노드 + 중첩 fixture 통과 |
| **P6 — Form Element Emitters** | Button/Link/Input/Select/Checkbox/Radio | T6.1 ~ T6.6 | 6 노드 fixture 통과 |
| **P7 — Special Emitters** | Divider/String/Emoji/PropPlaceholder/Error | T7.1 ~ T7.5 | 5 노드 fixture 통과 |
| **P8 — Round-Trip Suite** | parse(print(ast)) ≡ ast | T8.1 ~ T8.3 | 100+ fixture round-trip 100% |
| **P9 — Determinism & Performance** | 결정성, 10k 노드 < 100ms | T9.1 ~ T9.3 | 5000-case determinism, perf target 달성 |
| **P10 — Public API & Docs** | TS .d.ts, index, docs/ | T10.1 ~ T10.4 | npm import 가능, 문서 완비 |

---

## Phase 1 — Scaffolding

### T1.1 — 디렉터리 구조 & 빈 모듈 [blocks: T1.2~]
- 생성: `src/printer/v2/{V2Printer.res, V2Printer.resi, types/, inference/, layout/, emit/, __tests__/}` (design.md §1)
- **AC**:
  - `rescript build` 통과
  - 기존 V1/V2 parser, V2 renderer 빌드/테스트 회귀 0
  - dist에 새 파일 포함

### T1.2 — `PrintOptions.res` [requires: T1.1] [blocks: T1.4]
- design.md §2의 record + `defaultOptions()`
- charset/lineEnding/errorHandling 등 모든 enum 정의
- **AC**:
  - 기본값이 design.md §2와 일치 (`ASCII / LF / RenderComment / padding=1 / trimTrailing=false / maxColumns=None`)
  - 단위 테스트 통과

### T1.3 — `LayoutNode.res` 중간 표현 [requires: T1.1] [blocks: T3, T4, P5+]
- design.md §4의 재귀 record
- 빌더 헬퍼: `LayoutNode.fromAst(ast)` (사이즈/좌표 0으로 초기화)
- **AC**:
  - 모든 V2 AST variant에 대해 빈 LayoutNode 생성 OK
  - 순회 헬퍼 (`walk`, `mapChildren`) 단위 테스트 통과

### T1.4 — `V2Printer.print` 더미 진입점 [requires: T1.2, T1.3]
- 시그니처만 구현, 빈 문자열 + `\n` 반환
- TypeScript `.d.ts` 초안
- **AC**:
  - JS에서 `import { print } from "@wyreframe/v2-printer"` 동작
  - 호출 시 throw 없음

---

## Phase 2 — Canvas & Border Chars

### T2.1 — `BorderChars.res` (ASCII + Unicode 테이블) [requires: T1.1]
- design.md §10
- 두 charset set: `ascii`, `unicode`
- **AC**:
  - 11개 character role 모두 정의 (corners, edges, T-junctions, cross)
  - 단위 테스트: charset switch 동작

### T2.2 — `Canvas.res` (2D 버퍼) [requires: T1.1]
- design.md §11
- `make`, `set`, `writeText`, `drawBox`, `drawHLine`, `drawVLine`, `toString`
- 내부 mutable, 외부 인터페이스는 functional
- **AC**:
  - 10×20 canvas 만들고 박스 1개 그린 후 `toString()` 결과가 예상 ASCII와 byte-identical
  - line ending / trimTrailing 옵션 동작
  - 단위 테스트로 각 함수 검증

### T2.3 — `drawBox` 경계 정확성 [requires: T2.1, T2.2]
- 다양한 사이즈 (3×3, 5×7, 10×20) 박스 그리기
- ASCII와 Unicode 모두 검증
- **AC**:
  - 박스 모서리/엣지/꼭짓점이 BorderChars 테이블과 정확히 일치
  - golden fixture: `box_3x3.ascii.snap`, `box_3x3.unicode.snap` 등

---

## Phase 3 — Width/Height Inference

### T3.1 — `WidthInference.res` (bottom-up width pass) [requires: T1.3]
- design.md §5 표
- 모든 leaf 노드 위드 계산
- 컨테이너 위드 = max(child widths) + borders + padding
- **AC**:
  - 단위 테스트: 각 노드 variant의 width formula 검증
  - 단일 컨테이너 + 자식 3개 fixture에서 컨테이너 위드 정확
  - 깊이 3중 중첩 fixture 통과

### T3.2 — `HeightInference.res` (bottom-up height pass) [requires: T3.1]
- design.md §6
- Column: sum children. Row: max children. Mixed: sum groups.
- **AC**:
  - 각 direction의 height formula 단위 테스트
  - Mixed direction fixture 통과

### T3.3 — Block-level (Scene/Component) 사이즈 [requires: T3.1, T3.2]
- 헤더 라인 (`@scene:`, `@title:`, `@device:`, `@transition:`) 수 계산
- 자식 블록 사이즈 + 헤더 합산
- **AC**:
  - 모든 헤더 옵션 조합 fixture 통과
  - Component의 `@props:` 라인도 정확히 포함

---

## Phase 4 — Position Pass

### T4.1 — `PositionPass.res` (top-down) skeleton [requires: T3.1, T3.2]
- 부모 (x, y, innerW, innerH) → 자식 (x, y) 할당
- Column 기본 로직 (인덴트 후 순차 배치)
- **AC**:
  - 단일 컬럼 컨테이너 + 자식 3개에서 정확한 (x, y) 부여
  - 깊이 3중 중첩에서 좌표 누적 정확

### T4.2 — `DistributionSolver.res` (6 distribution 알고리즘) [requires: T4.1]
- design.md §8 테이블 전체
- `Equal`, `SpaceBetween`, `SpaceAround`, `Start`, `End`, `Center_`
- remainder는 leftmost-first
- **AC**:
  - 각 distribution에 대해 슬랙 5, 자식 3개 fixture에서 좌표 정확
  - 단위 테스트: 홀수 remainder도 결정적
  - 사이드: 짝수/홀수 슬랙, 1자식/2자식/4자식 edge case 통과

### T4.3 — `AlignmentSolver.res` (Column 자식의 Left/Center/Right) [requires: T4.1]
- design.md §9
- Row 컨테이너에서는 무시
- **AC**:
  - 3가지 alignment 각각 fixture 통과
  - Row 안 alignment 무시 동작 검증

### T4.4 — Mixed direction 처리 [requires: T4.2, T4.3]
- 그룹별 region 계산 → 그룹 내부에서 자체 direction 적용
- **AC**:
  - Row+Column 혼합 fixture 통과
  - 그룹 경계가 design.md §16 Open Q #6 (document order) 대로 정렬

---

## Phase 5 — Core Node Emitters

### T5.1 — `SceneEmitter.res` [requires: T2.2, T3.3]
- 헤더 라인 emit (`@scene:`, optional `@title:`, `@device:`, `@transition:`)
- 자식 블록 paint (PositionPass 결과 사용)
- **AC**:
  - Empty scene fixture 통과 (헤더 + 빈 영역)
  - 자식 1개/3개 fixture 통과

### T5.2 — `ComponentEmitter.res` [requires: T5.1]
- 헤더 + `@props:` 라인 + 자식 블록
- 프롭 syntax: `name`, `name?`, `name="default"`, comma-separated
- **AC**:
  - 0/1/3 props fixture 통과
  - optional/default 조합 fixture 통과

### T5.3 — `ContainerEmitter.res` [requires: T2.3, T4.1~T4.4]
- `Canvas.drawBox`로 외곽 그리고, 자식 emit 디스패치
- direction별로 PositionPass 결과 사용
- **AC**:
  - Row/Column/Mixed 각 direction × 6 distribution = 18 fixture 일부 통과 (P5에서 가능한 만큼)
  - 3중 중첩 컨테이너 fixture 통과

### T5.4 — `TextEmitter.res` [requires: T5.3]
- Column 안: alignment 반영 (Left/Center/Right offset)
- Row 안: PositionPass가 정한 (x, y) 그대로
- **AC**:
  - 3 alignment fixture 통과
  - Row 컨테이너 안 Text 위치 정확

### T5.5 — `NodeEmitterRegistry.res` (디스패치) [requires: T5.1~T5.4]
- AST variant → emitter 함수 매핑
- 미구현 variant는 임시로 ErrorEmitter fallback
- **AC**:
  - 모든 15개 variant에 대해 dispatch 가능
  - 단위 테스트로 각 variant 호출 후 canvas 변경 확인

---

## Phase 6 — Form Element Emitters

### T6.1 — `ButtonEmitter.res` [requires: T5.5]
- `[<text>]` syntax
- **AC**: alignment 적용, golden fixture `button.ascii.snap` 통과

### T6.2 — `LinkEmitter.res` [requires: T5.5]
- V2 link syntax (design.md §17 Open Q #3 — 구현 전 docs/syntax-v2.md 확인)
- **AC**: V2 spec 명시 syntax로 emit, fixture 통과

### T6.3 — `InputEmitter.res` [requires: T5.5]
- placeholder 있을 때 `[<placeholder>]`, 없을 때 `[___]`
- **AC**: placeholder 있는/없는 두 fixture 통과

### T6.4 — `SelectEmitter.res` [requires: T5.5]
- V2 select syntax (구현 전 spec 확인)
- 옵션 여러 개 처리
- **AC**: 1/3 옵션 fixture 통과

### T6.5 — `CheckboxEmitter.res` [requires: T5.5]
- `[x] label` 또는 `[ ] label`
- **AC**: checked/unchecked 두 fixture 통과

### T6.6 — `RadioEmitter.res` [requires: T5.5]
- `(x) label` 또는 `( ) label`
- group 정보는 ML 에서 추론 — 본 Printer는 V2 syntax 그대로 emit
- **AC**: checked/unchecked 두 fixture 통과

---

## Phase 7 — Special Emitters

### T7.1 — `DividerEmitter.res` [requires: T5.5]
- 부모 interior 전체 폭 가로선
- Bold style이면 `==` (또는 charset에 맞는 표기)
- **AC**: Normal/Bold 두 fixture 통과

### T7.2 — `StringEmitter.res` [requires: T5.5]
- 리터럴 텍스트 그대로 (whitespace 보존)
- **AC**: 공백/특수문자 포함 fixture 통과

### T7.3 — `EmojiEmitter.res` [requires: T5.5]
- shortcode → V2 syntax 그대로 (예: `:smile:`) — Printer는 *resolve 하지 않음*
- **AC**: shortcode 형태로 그대로 emit, fixture 통과

### T7.4 — `PropPlaceholderEmitter.res` [requires: T5.5]
- `{{name}}` 또는 `{{name=default}}` 그대로 emit
- 치환 안 함 (Requirement 11 #4)
- **AC**: default 있는/없는 두 fixture 통과

### T7.5 — `ErrorEmitter.res` (3 모드) [requires: T5.5]
- Skip / RenderComment / Throw
- **AC**: 3 모드 각각 fixture 통과 + Throw 모드 예외 검증

---

## Phase 8 — Round-Trip Suite

### T8.1 — `Compare.res` (semantic AST equality) [blocks: T8.2]
- design.md §13의 `semanticallyEqual` 구현
- sourceLocation / bounds 무시, 나머지 비교
- AST diff 출력 (실패 시 분석용)
- **AC**:
  - 같은 AST → equal
  - 한 노드만 다른 AST → not equal + 정확한 diff 위치
  - 단위 테스트 다수

### T8.2 — Round-trip corpus 100+ fixtures [requires: T8.1, P5~P7 완료]
- design.md §13의 fixture 목록 작성
  - empty_scene, single_button, login_form, deep_nesting, all_distributions, all_alignments, mixed_layout, unicode_charset, component_with_props, etc.
- 각 fixture에 대해:
  - parse(print(AST)) 가 의미적으로 같은지
  - print(parse(print(AST))) 가 byte-identical 한지 (idempotency)
- **AC**:
  - 100+ fixture 모두 통과
  - CI 에서 자동 실행

### T8.3 — Round-trip 회귀 게이트
- V2 Parser / V2 Printer 변경 PR 시 자동 round-trip 슈트 실행
- 실패 시 PR 차단
- **AC**:
  - GitHub Actions / CI에 통합
  - 실패 시 diff + 입력 AST 출력

---

## Phase 9 — Determinism & Performance

### T9.1 — Determinism 테스트 슈트 [requires: P5~P7]
- 50+ AST fixture × 100회 반복 = 5000 케이스
- 모두 byte-identical
- **AC**: 5000/5000 통과, 1건이라도 실패 시 alert

### T9.2 — 벤치마크 인프라 [requires: P5~P7]
- 1k/5k/10k 노드 합성 AST
- 5회 평균 + p95 측정
- **AC**:
  - 10k 노드 < 100ms (p95)
  - 결과를 `benchmarks.md` 에 기록

### T9.3 — Hot-path 최적화 (필요시) [requires: T9.2]
- target 미달 시:
  1. Buffer 기반 string assembly
  2. Canvas allocation 사전 사이즈 계산
  3. PositionPass의 array allocation 최소화
- **AC**: target 달성 또는 미달 사유 문서화

---

## Phase 10 — Public API & Docs

### T10.1 — `index.ts` re-export & package exports [requires: P9]
- `package.json`:
  - `./v2-printer` → V2 Printer
- TypeScript `.d.ts` 완성
- **AC**:
  - `import { print } from "@wyreframe/v2-printer"` 동작
  - `tsc --noEmit` 외부 시뮬레이션 통과

### T10.2 — `docs/api.md` 에 V2 Printer 섹션
- API, 옵션, round-trip 특성 명시
- 사용 예: V2 Renderer와 짝을 이루는 setup
- **AC**: lint 통과, 코드 샘플이 실행 가능

### T10.3 — `examples/v2-printer/`
- 최소 3개: roundtrip-demo, formatter-cli, snapshot-test
- **AC**: 각 example 실행 시 동작 확인

### T10.4 — Self-improvement.md 참조 연결 [blocks: ml-parser/self-improvement.md 업데이트 작업]
- `ml-parser/self-improvement.md`의 Phase 0 prerequisite과 cross-link
- Loop A의 cycle 닫는 컴포넌트로 V2 Printer 명시
- **AC**: self-improvement.md가 본 spec을 §4.2 컴포넌트로 참조

---

## Acceptance Gate per Phase

- **Phase 1**: 빌드 통과 + 회귀 0
- **Phase 2**: 박스 1개 그리기 byte-identical (ASCII + Unicode)
- **Phase 3**: 모든 노드 사이즈 정확
- **Phase 4**: 6 distribution × 3 direction = 18 케이스 좌표 정확
- **Phase 5**: 4 코어 노드 + 3중 중첩 통과
- **Phase 6**: 6 폼 요소 통과
- **Phase 7**: 5 특수 노드 통과
- **Phase 8**: 100+ fixture round-trip 100% + idempotency 100%
- **Phase 9**: 5000/5000 determinism + 10k 노드 <100ms
- **Phase 10**: npm import + 문서 완비 + self-improvement.md 연결

---

## Risk Log

| 리스크 | 영향 | 완화 |
| --- | --- | --- |
| Round-trip 실패 (parser와 부정합) | spec 자체 무효화 | T8.2를 가능한 한 일찍 작은 fixture로 시작 (P5 끝나자마자 mini-roundtrip), 충돌 발견 시 V2 syntax 결정 회의 소집 |
| Distribution rounding 결정성 깨짐 | self-improvement cycle 신뢰 붕괴 | T4.2 단위 테스트에서 100회 반복 byte-identical 검증 |
| V2 syntax 미정 부분 (Select, Link 정확한 표기) | 구현 막힘 | P6 시작 전 `docs/syntax-v2.md` 정합성 PR 선행 — 미정 항목 한 번에 정리 |
| Performance target 미달 | self-improvement loop throughput 저하 | T9.3 최적화 + 필요 시 Canvas 구조 재설계 |
| Unicode width 가정 위반 (CJK/emoji wide) | 출력 좌표 어긋남 | 명시적으로 v0.1 제한 문서화, fail-loud + 별도 RFC |
| ErrorNode round-trip 불가 | spec 모호함 노출 | Requirement 12에 명시: error-free AST만 round-trip 보장 |

---

## Out of Scope

- V2 syntax 자체 변경 (별도 syntax RFC).
- V1 AST 인쇄.
- 텍스트 wrapping / 자동 줄바꿈.
- 색상/스타일.
- 비-monospace 폰트.
- 증분 업데이트.
- 인쇄 결과의 lint / format (별도 도구).
