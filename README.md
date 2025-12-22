# Wyreframe

> ASCII 와이어프레임을 실제 동작하는 HTML/UI로 변환하는 라이브러리

[![npm version](https://img.shields.io/npm/v/wyreframe.svg)](https://www.npmjs.com/package/wyreframe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```
+---------------------------+
|      'WYREFRAME'          |     ASCII로 그리면
|  +---------------------+  |         ↓
|  | #email              |  |     HTML로 변환!
|  +---------------------+  |
|       [ Login ]           |
+---------------------------+
```

## 설치

```bash
npm install wyreframe
```

## 빠른 시작

```javascript
import { createUI } from 'wyreframe';

const ui = `
@scene: login

+---------------------------+
|       'WYREFRAME'         |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|       [ Login ]           |
+---------------------------+

#email:
  placeholder: "이메일을 입력하세요"

[Login]:
  @click -> goto(dashboard, slide-left)
`;

const result = createUI(ui);

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
}
```

## 문법 요약

| 문법 | 설명 | 예시 |
|------|------|------|
| `+---+` | 박스/컨테이너 | `<div>` |
| `[ Text ]` | 버튼 | `<button>` |
| `#id` | 입력 필드 | `<input>` |
| `"text"` | 링크 | `<a>` |
| `'text'` | 강조 텍스트 | 타이틀, 헤딩 |
| `[x]` / `[ ]` | 체크박스 | `<input type="checkbox">` |
| `---` | 씬 구분자 | 멀티 씬 |

## API

```javascript
import { parse, render, createUI, createUIOrThrow } from 'wyreframe';

// 파싱만
const result = parse(text);

// 렌더링만
const { root, sceneManager } = render(ast);

// 파싱 + 렌더링 (권장)
const result = createUI(text);

// 에러 시 throw
const { root, sceneManager } = createUIOrThrow(text);
```

### SceneManager

```javascript
sceneManager.goto('dashboard');           // 씬 이동
sceneManager.getCurrentScene();           // 현재 씬
sceneManager.getSceneIds();               // 전체 씬 목록
```

## 인터랙션

```yaml
#email:
  placeholder: "이메일"

[Login]:
  variant: primary
  @click -> goto(dashboard, slide-left)
```

**전환 효과:** `fade`, `slide-left`, `slide-right`, `zoom`

## 문서

- [파서 아키텍처](docs/PARSER_ARCHITECTURE.md)
- [테스트 가이드](docs/TESTING.md)
- [예제](examples/index.html)

## 개발

```bash
npm install
npm run res:build    # ReScript 빌드
npm run dev          # 개발 서버 (http://localhost:3000/examples)
npm test             # 테스트
```

## 라이선스

MIT License
