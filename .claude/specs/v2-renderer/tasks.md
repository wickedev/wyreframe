# Wyreframe V2 Renderer — Implementation Tasks

## Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Implements**: `requirements.md` + `design.md` in this directory
- **Style**: 각 task는 *단일 PR로 land 가능한 크기*. acceptance criteria가 명확히 검증 가능.
- **Dependency tracking**: `[blocks: T#]` / `[requires: T#]` 를 task 헤더에 명시.

---

## Phase Summary

| Phase | 목적 | Tasks | 합격선 |
| --- | --- | --- | --- |
| **P1 — Scaffolding** | 디렉터리, 타입, 더미 진입점 | T1.1 ~ T1.4 | `renderToString` 호출 가능 (빈 출력) |
| **P2 — Output backend** | IR + 두 백엔드 (string / DOM) | T2.1 ~ T2.5 | IR → HTML 문자열 결정적 출력 |
| **P3 — Layout & alignment** | 카테고리 → 클래스 | T3.1 ~ T3.3 | 모든 layout/alignment fixture pass |
| **P4 — Core nodes** | Scene, Component, Container, Text | T4.1 ~ T4.5 | 4 노드 fixture pass + 중첩 동작 |
| **P5 — Form elements** | Button, Link, Input, Select, Checkbox, Radio | T5.1 ~ T5.7 | 6 노드 fixture pass + radio group 추론 |
| **P6 — Content & special** | Divider, String, Emoji, PropPlaceholder, Error | T6.1 ~ T6.5 | 5 노드 fixture pass + 옵션 동작 |
| **P7 — Context & diagnostics** | RenderContext, 경고, 진단 API | T7.1 ~ T7.3 | duplicate ID 등 경고 노출 |
| **P8 — Accessibility & determinism** | ARIA, 정렬 일관성 | T8.1 ~ T8.3 | a11y test + determinism test pass |
| **P9 — Performance** | 10k 노드 < 100ms | T9.1 ~ T9.2 | 벤치마크 target 달성 |
| **P10 — Public API & docs** | TS .d.ts, index, README, docs/ | T10.1 ~ T10.4 | 외부에서 import 가능, 문서 완비 |

---

## Phase 1 — Scaffolding

### T1.1 — 디렉터리 구조 & 빈 모듈 생성
- 생성: `src/renderer/v2/{V2Renderer.res, V2Renderer.resi, types/, elements/, layout/, output/, css/, emoji/, __tests__/}` (design.md §1)
- 각 모듈 빈 정의 + 빌드 통과
- **AC**:
  - `rescript build` 성공
  - `npm test` 가 변경 후에도 모두 pass (V1 회귀 0)
  - 새로 추가된 파일이 dist에 포함됨

### T1.2 — `RenderOptions.res` 정의 [blocks: T1.3]
- design.md §2의 record + 기본값 함수 `defaultOptions()`
- ReScript 타입 export, `.resi` 노출
- **AC**:
  - 모든 필드가 기본값 보유
  - 유닛 테스트: `defaultOptions()`이 design.md §2와 byte-identical 값

### T1.3 — `Ir.res` (intermediate output node) [requires: T1.2]
- design.md §3 의 `outputNode` 재귀 타입
- pretty-print 유틸 (디버그용)
- **AC**:
  - 모든 child variant 표현 가능 (Element/Text/Raw)
  - 컴파일 + 단위 테스트 (수동 IR → 문자열 변환 sanity check)

### T1.4 — `V2Renderer.renderToString` 더미 진입점 [requires: T1.2, T1.3]
- 시그니처만 구현, 빈 문자열 반환 + 옵션 무시
- TypeScript `.d.ts` 초안 작성 (V2Parser 패턴 모방)
- **AC**:
  - JS 환경에서 `import { renderToString } from "@wyreframe/v2-renderer"` 가능
  - 호출 시 throw 없음
  - 타입 검사 통과

---

## Phase 2 — Output Backend

### T2.1 — `HtmlBuilder.res` (string emit) [requires: T1.3]
- design.md §8.1
- escape 규칙, 속성 순서 정렬, self-closing tag
- 단위 테스트: 알려진 IR → 알려진 문자열
- **AC**:
  - `<`, `>`, `&`, `"`, `'` 모두 escape
  - 같은 IR → 같은 문자열 (deterministic) — 50회 반복 테스트
  - self-closing tag (`<input/>`, `<hr/>`) 처리

### T2.2 — `DomBuilder.res` (DOM emit) [requires: T1.3]
- design.md §8.2
- 기존 V1 `DomBindings`를 공유 모듈로 추출 (`src/renderer/shared/DomBindings.res`)
- IR → 실제 DOM 노드 생성
- **AC**:
  - jsdom 테스트 환경에서 IR → element 생성 OK
  - 속성/data-attr/class 정확히 설정
  - V1 renderer가 동일 DomBindings 사용 후에도 회귀 없음

### T2.3 — Attribute/class 직렬화 결정성 [requires: T2.1]
- design.md §9 명세 구현: id → class → 알파벳 → data-* 알파벳
- class 배열 alphabetical sort
- **AC**:
  - 50개 fixture에 대해 두 번 렌더 결과 byte-identical
  - 속성 순서가 design.md 명세와 일치

### T2.4 — `RenderHandle` 와 dispose [requires: T2.2]
- design.md §8.2의 `renderHandle` 구현
- `dispose()`: 자식 모두 제거 + 등록된 이벤트 리스너 정리
- Phase 1의 `update()`: 전체 재렌더 (clear root + render again)
- **AC**:
  - `dispose()` 후 root.children === 0
  - `update(newAst)` 후 DOM이 newAst를 반영
  - 동일 ast로 `update()` 호출 시 byte-identical DOM

### T2.5 — `renderToStringWithDiagnostics` [requires: T2.1, T7.1]
- design.md §7
- `(html: string, warnings: array<warning>)` 튜플 반환
- **AC**:
  - duplicate ID 입력에서 warning 정확히 1개
  - 정상 입력에서 warnings 빈 배열

---

## Phase 3 — Layout & Alignment

### T3.1 — `LayoutClasses.res` [requires: T1.1]
- design.md §5
- `directionClass`, `distributionClass`
- **AC**:
  - 모든 enum value cover (총 9개 변환)
  - 단위 테스트: 각 enum → 정확한 클래스 문자열

### T3.2 — `AlignmentClasses.res` [requires: T1.1]
- design.md §5
- **AC**: 3 enum 모두 cover, 단위 테스트 통과

### T3.3 — 레퍼런스 스타일시트 `wyreframe-v2.css` [requires: T3.1, T3.2]
- design.md §13
- package.json에 `./style.css` 서브경로 export 추가
- **AC**:
  - `import "@wyreframe/v2-renderer/style.css"` 동작
  - 클래스명이 §13 표와 1:1 일치
  - 빌드 산출물에 포함됨

---

## Phase 4 — Core Nodes (Scene, Component, Container, Text)

### T4.1 — `SceneRenderer.res` [requires: T2.1, T3.1, T3.2]
- design.md §4 표의 Scene 행
- title/device/transition data-attr 처리
- **AC**:
  - 빈 scene → `<section class="wf-scene" data-wf-slug="..." />`
  - device 있을 때 class에 `wf-device-<x>` 포함
  - golden fixture `scene/basic.snap`, `scene/with-device.snap`, `scene/with-transition.snap` 통과

### T4.2 — `ComponentRenderer.res` [requires: T2.1]
- props metadata 처리
- **AC**:
  - 각 prop 이 `data-wf-prop-<name>` 로 노출
  - optional prop 은 값 `"optional"`, required 는 `"required"`, default 있으면 default 값
  - golden fixture 통과

### T4.3 — `ContainerRenderer.res` [requires: T3.1, T3.2, T4.1]
- direction/distribution 클래스 부착
- 자식 재귀 렌더 (디스패치 레지스트리 호출)
- **AC**:
  - Row + SpaceBetween → `wf-direction-row wf-dist-space-between` 모두 포함
  - 자식 노드들이 document order로 출력
  - 중첩 container 동작 (3 레벨 fixture)

### T4.4 — `TextRenderer.res` (block + inline 분기) [requires: T4.3]
- design.md §4: 부모 container의 direction이 Row 면 `<span>`, 아니면 `<p>`
- **AC**:
  - Column 컨테이너 안 Text → `<p class="wf-text">`
  - Row 컨테이너 안 Text → `<span class="wf-text">`
  - alignment 클래스 부착
  - golden fixture 통과

### T4.5 — `ElementDispatcher.res` (디스패치 레지스트리) [requires: T4.1~T4.4]
- design.md §3 — 노드 variant → 렌더러 함수 매핑
- 미구현 노드는 임시 `ErrorRenderer.fallback` 호출
- **AC**:
  - 모든 V2 AST variant에 대해 dispatch 가능 (P5, P6에서 채워질 변종 포함)
  - 단위 테스트: 각 variant 호출 후 IR 반환

---

## Phase 5 — Form Elements

### T5.1 — `ButtonRenderer.res` [requires: T4.5]
- design.md §4
- `<button type="button">` + text + class + data-attr
- **AC**: golden fixture `elements/button.snap` 통과, alignment 클래스 적용

### T5.2 — `LinkRenderer.res` [requires: T4.5]
- `<a>` (no href)
- **AC**: golden fixture `elements/link.snap` 통과

### T5.3 — `InputRenderer.res` [requires: T4.5]
- `<input>` + placeholder
- **AC**: placeholder 있는/없는 두 fixture 통과

### T5.4 — `SelectRenderer.res` [requires: T4.5]
- `<select>` + `<option>`s
- **AC**: 3 option fixture, option text 보존, document order

### T5.5 — `CheckboxRenderer.res` [requires: T4.5]
- `<label>` wrapping `<input type="checkbox">` + `<span>`
- checked state → `data-wf-checked` + DOM checked
- **AC**:
  - 체크된/안된 두 fixture 통과
  - label click이 checkbox toggle 하는지 DOM 모드 테스트

### T5.6 — `RadioRenderer.res` (single-node level) [requires: T4.5]
- `<label>` wrapping `<input type="radio" name="..">` + `<span>`
- name 은 RenderContext.radioGroups 에서 조회 (T5.7에서 채움)
- **AC**: 단일 radio fixture 통과

### T5.7 — Radio group 추론 [requires: T5.6, T7.1]
- design.md §6 알고리즘
- pre-pass 에서 RenderContext.radioGroups 구축
- **AC**:
  - 같은 부모 안 연속 3개 radio → 같은 name
  - 사이에 비-radio 형제 끼면 다른 group
  - fixture `composition/radio-groups.snap` 통과
  - 결정성 보장: 같은 AST → 같은 group name

---

## Phase 6 — Content & Special Nodes

### T6.1 — `DividerRenderer.res` [requires: T4.5]
- `<hr>` + Bold style 클래스
- **AC**: normal/bold 두 fixture 통과

### T6.2 — `StringRenderer.res` [requires: T4.5]
- `<span class="wf-string">` + 리터럴 텍스트
- whitespace 보존
- **AC**: 공백/특수문자 포함 fixture 통과 (escape 동작 확인)

### T6.3 — `EmojiRenderer.res` + Default emoji table [requires: T4.5]
- design.md §1 (`emoji/DefaultEmojiTable.res`)
- ~200 common shortcodes
- `aria-label="<shortcode>"`
- 옵션 `emojiResolver` 우선, fallback 으로 table
- **AC**:
  - `:smile:` → 😄 + `aria-label="smile"`
  - 미지의 shortcode → `:unknown:` 리터럴 + warning
  - 커스텀 resolver 테스트

### T6.4 — `PropPlaceholderRenderer.res` [requires: T4.5, T7.1]
- design.md §4 + Requirement 8
- 옵션 `componentPropValues` 우선, default 차선, 미해결 시 marker
- 미해결은 warning 발생
- **AC**:
  - 값 제공 시 인라인 텍스트로 치환
  - default 사용
  - 미해결 시 `<span class="wf-prop-missing">{{name}}</span>` + warning
  - 치환 텍스트가 wireframe 문법으로 *재파싱되지 않음* 확인

### T6.5 — `ErrorRenderer.res` [requires: T4.5, T7.1]
- 옵션 `errorHandling`: Skip / RenderMarker / Throw
- Skip: 빈 IR
- RenderMarker: `<span class="wf-error" role="alert">…</span>`
- Throw: 타입드 예외
- **AC**: 3 모드 각각 fixture 통과

---

## Phase 7 — Context & Diagnostics

### T7.1 — `RenderContext.res` + pre-pass [blocks: T5.7, T6.4, T6.5]
- design.md §7
- AST 한 번 walk: seenIds, radioGroups, propValues, warnings 슬롯 준비
- **AC**:
  - 단위 테스트: duplicate ID 입력 → warning 1개
  - radioGroups 가 design.md §6 알고리즘대로 채워짐

### T7.2 — Warning 컬렉션 & 노출
- 모든 렌더러가 `RenderContext`에 warning push
- `renderToStringWithDiagnostics` (T2.5) 가 노출
- `RenderHandle.warnings` 가 노출
- **AC**:
  - 종합 fixture에서 모든 warning 종류 발생 후 정확히 수집

### T7.3 — TypeScript 에러 타입 export
- `V2Renderer.d.ts`에 `RenderWarning`, `RenderError` 노출
- **AC**: TS 컨슈머가 warning 배열을 타입 안전하게 사용

---

## Phase 8 — Accessibility & Determinism

### T8.1 — Accessibility 자동 검증 테스트
- design.md §11 모든 규칙
- jsdom + 수동 어설션 (또는 `axe-core` 통합)
- **AC**:
  - 모든 golden fixture가 a11y 규칙 통과
  - 회귀 시 명확한 실패 메시지

### T8.2 — Determinism 테스트 슈트
- 50+ 다양한 AST fixture
- 각각 100회 렌더 → 모두 byte-identical
- 다른 머신/Node 버전에서도 일관성 (CI matrix)
- **AC**: 100회 × 50 fixture = 5000 케이스 100% byte-identical

### T8.3 — 합성 ID 결정성 검증
- design.md §9 #4
- 같은 (salt, row, col) → 같은 ID
- 다른 salt → 다른 ID
- **AC**: 단위 테스트 + radio group / prop missing 시나리오에서 합성 ID 사용 검증

---

## Phase 9 — Performance

### T9.1 — 벤치마크 인프라
- `__tests__/performance_test.res`
- 1k / 5k / 10k 노드 AST 합성 후 시간 측정
- 5회 평균 + p95
- **AC**:
  - 10k 노드 renderToString p95 < 100ms (M1 클래스 기준)
  - 결과를 `benchmarks.md` 로 저장 (regression 추적)

### T9.2 — Hot-path 최적화 (필요 시)
- T9.1 결과가 target 미달이면 다음 순서로 시도:
  1. `Buffer.t` 기반 문자열 빌더
  2. class array dedupe 캐시
  3. attribute 정렬 사전 계산
- **AC**: target 달성 또는 미달 사유 문서화

---

## Phase 10 — Public API & Documentation

### T10.1 — `index.ts` re-export & 패키지 export 맵
- `package.json` 의 `exports` 필드:
  - `.` → V1 (기존 그대로)
  - `./v2-renderer` → V2 renderer
  - `./v2-renderer/style.css` → 레퍼런스 시트
- TypeScript `.d.ts` 완성 (모든 옵션, 반환 타입)
- **AC**:
  - `import { renderToString } from "@wyreframe/v2-renderer"` 동작
  - `tsc --noEmit` 통과 (외부 컨슈머 시뮬)

### T10.2 — 문서 업데이트 (`docs/api.md` v2 섹션)
- V2 Renderer API 추가
- 옵션 표, 출력 예시, css 사용법, 마이그레이션 가이드
- V1 사용자를 위한 "이미 사용 중이라면 변경 없음" 명시
- **AC**: lint / 링크 체크 통과, 새 코드 샘플들이 실제로 동작 (doctest)

### T10.3 — `examples/v2-renderer/` 샘플 페이지
- 최소 3개: login form, dashboard 일부, error case
- 각 example 은 V2 syntax → renderToString → HTML preview + CSS 로딩
- **AC**: 브라우저에서 열어 정상 표시

### T10.4 — Self-improvement.md prerequisite 충족 선언
- `ml-parser/self-improvement.md` Phase 0 의 "V1 렌더러" 항목을 V2 Renderer로 갱신 (별도 PR로 self-improvement.md 수정)
- forward path (V2 → HTML) 의 자가 검증 활용 준비 완료
- **AC**: self-improvement.md 가 본 스펙을 참조하도록 cross-link 업데이트

---

## Acceptance Gate per Phase

각 phase 종료 조건:

- **Phase 1**: 새 모듈 빌드 통과 + V1 회귀 0
- **Phase 2**: IR → HTML 결정적 출력, jsdom 모드 동작
- **Phase 3**: layout/alignment 클래스 변환 fixture 통과
- **Phase 4**: Scene/Component/Container/Text 4종 fixture 통과 + 3 레벨 중첩 동작
- **Phase 5**: 6 폼 요소 fixture + radio group 추론 동작
- **Phase 6**: Divider/String/Emoji/PropPlaceholder/Error 5종 fixture 통과
- **Phase 7**: 진단 API에서 모든 warning 종류 노출
- **Phase 8**: a11y test + determinism test 100% pass
- **Phase 9**: 10k 노드 < 100ms
- **Phase 10**: 외부에서 npm 패키지로 import + 문서 완비

---

## Risk Log

| 리스크 | 영향 | 완화 |
| --- | --- | --- |
| V1 DomBindings 공유 모듈 추출 시 V1 회귀 | V1 사용자 영향 | 추출 PR을 단독으로 land, V1 전체 테스트 + 수동 데모 통과 후 다음 phase 진행 |
| Radio group 추론 휴리스틱이 실사용과 어긋남 | 잘못된 그룹화 → UX 망가짐 | Phase 5 종료 시 실제 와이어프레임 샘플 10개로 수동 검증 |
| 10k 노드 < 100ms target 미달 | 인터랙티브 에디터 사용성 저하 | T9.2 최적화 → 필요 시 IR 구조 재설계 (Phase 9 buffer) |
| 결정성 위반 (속성 순서, 합성 ID 등) | 자가 개선 cycle 검증 신뢰성 붕괴 | Phase 8 의 5000-케이스 determinism 테스트가 사전 검출 |
| TypeScript .d.ts 작성 누락 → 외부 사용성 저하 | DX 저하 | Phase 1 부터 .d.ts 초안 + Phase 10 검증 |
| reference CSS가 사용자 스타일과 충돌 | 도입 거부감 | sub-export 로 opt-in, 명확한 docs, classPrefix 옵션 |

---

## Out of Scope (본 문서 기준)

- V2 AST → ASCII 역렌더러 (별도 spec `v2-ascii-printer`).
- Incremental DOM diff (Phase 2 capability — design.md §8.2).
- 서버 사이드 hydration handshake.
- Web Components 출력 모드.
- 인터랙션 DSL.
- V1 → V2 마이그레이션 도구 (별도 spec 필요 시).
