// PackageJson.test.ts
// Codex-review-driven regressions, round 44.
// Guards the package lifecycle:
//   1. `prepare` must NOT run the full ReScript build, which would pull in
//      `__tests__` modules importing `rescript-vitest` (a devDependency).
//      `npm install --omit=dev` would then fail before the package is usable.
//   2. `build` must invoke `ts:check`, since the `wyreframe/parser/v2`
//      subpath `.d.ts` is otherwise covered by no other published-build step.

import { describe, test, expect } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const pkgPath = resolve(here, "../../../../../package.json");
const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));

describe("Regression P2: package.json lifecycle (Codex round 44)", () => {
  test("no `prepare` script that runs the ReScript build (would break --omit=dev installs)", () => {
    const prepare = pkg.scripts?.prepare as string | undefined;
    if (prepare !== undefined) {
      // Allowed forms: absent, or something that does NOT invoke `build`/`res:build`/`rescript`.
      expect(prepare).not.toMatch(/\b(npm run build|res:build|rescript)\b/);
    }
  });

  test("`build` runs `ts:check` so subpath .d.ts regressions are caught", () => {
    const build = pkg.scripts?.build as string | undefined;
    expect(build).toBeDefined();
    expect(build).toMatch(/\bts:check\b/);
  });

  test("`prepublishOnly` still runs the full build before publish", () => {
    const prepub = pkg.scripts?.prepublishOnly as string | undefined;
    expect(prepub).toBeDefined();
    expect(prepub).toMatch(/\b(npm run build|build)\b/);
  });
});
