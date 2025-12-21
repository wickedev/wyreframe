# Wyreframe

> ASCII 와이어프레임 + 인터랙션 DSL → HTML 변환 라이브러리

[![npm version](https://img.shields.io/npm/v/wyreframe.svg)](https://www.npmjs.com/package/wyreframe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

텍스트 기반 와이어프레임을 실제 동작하는 HTML로 변환합니다. 씬 전환, 인터랙션, 애니메이션까지 DSL로 정의할 수 있습니다.

## 특징

- **ASCII 와이어프레임**: 텍스트로 UI 레이아웃 정의
- **자동 정렬 감지**: 박스 내 위치에 따라 좌/중앙/우 정렬 자동 적용
- **인터랙션 DSL**: 클릭 이벤트, 씬 전환 등 상호작용 정의
- **부드러운 씬 전환**: fade, slide, zoom 애니메이션 지원
- **와이어프레임 스타일**: 모노스페이스 폰트, 1px 테두리의 목업 스타일

## 설치

```bash
npm install wyreframe
```

## 데모 실행

```bash
git clone https://github.com/user/wyreframe.git
cd wyreframe
npm run dev
# http://localhost:3000 에서 데모 확인
```

## 빠른 시작

```javascript
import { parse, render } from 'wyreframe';

const wireframe = `
@scene: login
@title: 로그인

+---------------------------+
|                           |
|      * WYREFRAME          |
|                           |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #password           |  |
|  +---------------------+  |
|                           |
|     [ Login ]             |
|                           |
|  "Forgot password?"       |
+---------------------------+

---

@scene: dashboard
@title: 대시보드

+---------------------------+
|  Dashboard      [ Logout ]|
+===========================+
|                           |
|  Welcome back!            |
|                           |
+--Stats-------------------+|
|   Users: 1,234            |
|   Active: 567             |
+-------------------------+ |
+---------------------------+
`;

const interactions = `
@scene: login

#email:
  type: input
  placeholder: "이메일을 입력하세요"

#password:
  type: input
  variant: password
  placeholder: "비밀번호"

[Login]:
  type: button
  variant: primary
  @click -> goto(dashboard, slide-left)

"Forgot password?":
  type: link
  @click -> goto(forgot, slide-left)

---

@scene: dashboard

[Logout]:
  type: button
  variant: ghost
  @click -> goto(login, fade)
`;

// 파싱 및 렌더링
const { sceneManager } = render(parse(wireframe, interactions), document.getElementById('app'));

// 콘솔에서 씬 전환 테스트
// sceneManager.goto('dashboard', 'zoom')
```

## ASCII 와이어프레임 문법

### 기본 요소

| 문법 | 설명 | HTML 출력 |
|------|------|-----------|
| `+---+` | 박스/컨테이너 | `<div class="wf-box">` |
| `+--Name--+` | 이름이 있는 박스 | `<div class="wf-box" data-name="Name">` |
| `[ Text ]` | 버튼 | `<button>` |
| `#id` | 입력 필드 | `<input>` |
| `"text"` | 링크 | `<a>` |
| `* text` | 강조 텍스트 (볼드) | `<p class="wf-text emphasis">` |
| `[x]` / `[ ]` | 체크박스 | `<input type="checkbox">` |
| `+===+` | 구분선 | `<hr>` |
| `---` | 씬 구분자 | 새로운 씬 시작 |

### 자동 정렬 감지

박스 경계선(`-` 또는 `=`)의 개수로 전체 너비를 계산하고, 콘텐츠의 위치에 따라 자동으로 정렬을 결정합니다:

```
+---------------------------+
|  Left aligned             |  ← 좌측 정렬 (기본)
|      Center aligned       |  ← 중앙 정렬
|             Right aligned |  ← 우측 정렬
+---------------------------+
```

- **텍스트**: 항상 좌측 정렬 (읽기 쉬움)
- **강조 텍스트 (`* text`)**: 위치에 따라 정렬 적용
- **버튼/링크**: 위치에 따라 정렬 적용

### 이름이 있는 섹션

박스 내부에 `+--SectionName--+` 형식으로 섹션을 만들 수 있습니다:

```
+---------------------------+
|  Dashboard                |
+===========================+
|                           |
+--Stats-------------------+|
|   Users: 1,234            |
|   Active: 567             |
+-------------------------+ |
|                           |
+--Quick Actions-----------+|
|  [ New Post ]             |
|  [ Settings ]             |
+---------------------------+
```

### 레이아웃 예시

```
+---------------------------+
|      * WYREFRAME          |  ← 강조 + 중앙 정렬
|                           |
|  +---------------------+  |
|  | #email              |  |  ← 입력 필드
|  +---------------------+  |
|                           |
|     [ Login ]             |  ← 버튼 (중앙)
|                           |
|  "Forgot password?"       |  ← 링크 (좌측)
+---------------------------+
```

## 인터랙션 DSL

### 요소 선택자

```yaml
#email:              # ID로 선택
[Login]:             # 버튼 텍스트로 선택
"Forgot password?":  # 링크 텍스트로 선택
```

### 입력 필드 설정

```yaml
#email:
  type: input
  placeholder: "이메일을 입력하세요"

#password:
  type: input
  variant: password              # password 타입으로 변경
  placeholder: "비밀번호"
```

### 버튼 스타일

```yaml
[Submit]:
  type: button
  variant: primary               # 기본 버튼

[Cancel]:
  type: button
  variant: secondary             # 보조 버튼

[Back]:
  type: button
  variant: ghost                 # 고스트 버튼 (투명 배경)
```

### 클릭 이벤트와 씬 전환

```yaml
[Login]:
  @click -> goto(dashboard)              # 기본 전환 (fade)
  @click -> goto(dashboard, slide-left)  # 슬라이드 전환
  @click -> goto(dashboard, zoom)        # 줌 전환

[Back]:
  @click -> goto(login, slide-right)     # 뒤로 가기 느낌
```

## 씬 (Scene) 시스템

### 씬 정의

```
@scene: home
@title: "홈페이지"
@transition: fade

+---------------------------+
|  Welcome to Home          |
|                           |
|  [ Go to About ]          |
+---------------------------+
```

### 씬 전환 타입

| 전환 효과 | 설명 |
|-----------|------|
| `fade` | 페이드 인/아웃 (기본값) |
| `slide-left` | 새 씬이 오른쪽에서 들어옴 |
| `slide-right` | 새 씬이 왼쪽에서 들어옴 |
| `zoom` | 줌 인/아웃 |

**전환 애니메이션 특징:**
- 350ms 듀레이션, Material Design 이징 적용
- 이전/다음 씬이 동시에 애니메이션 (부드러운 전환)
- GPU 가속 (`will-change`, `transform`)
- 연속 클릭 방지 (전환 중 추가 전환 무시)

### 씬 히스토리

```yaml
[Back]:
  @click -> back()         # 이전 씬으로

[Forward]:
  @click -> forward()      # 다음 씬으로

[Home]:
  @click -> goto(home, replace: true)  # 히스토리 교체
```

## API

### parse(wireframe, interactions?)

와이어프레임과 인터랙션 DSL을 파싱합니다.

```javascript
const ast = parse(wireframe, interactions);
```

### render(ast, container, options?)

파싱된 AST를 DOM에 렌더링합니다. `sceneManager`를 반환하여 프로그래밍 방식으로 씬 전환을 제어할 수 있습니다.

```javascript
const { app, sceneManager } = render(ast, document.getElementById('root'));

// 프로그래밍 방식으로 씬 전환
sceneManager.goto('dashboard', 'slide-left');
sceneManager.back();   // 이전 씬으로
sceneManager.forward(); // 다음 씬으로
```

### toHTML(ast, options?)

정적 HTML 문자열을 생성합니다.

```javascript
const html = toHTML(ast, { minify: true });
```

## 브라우저 지원

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 라이선스

MIT License

## 기여하기

이슈와 PR을 환영합니다! [CONTRIBUTING.md](CONTRIBUTING.md)를 참고해주세요.
