/**
 * Tests for TypeScript API wrapper input validation
 *
 * These tests verify that render() provides helpful error messages
 * when called with incorrect arguments (Issue #1).
 */

import { describe, test, expect, vi } from 'vitest';
import { parse, render, createUI } from './index';
import type { AST, ParseResult, OnSceneChangeCallback, DeviceType, RenderOptions } from './index';

describe('render() input validation (Issue #1)', () => {
  const validWireframe = `
@scene: test

+-------+
| Hello |
+-------+
`;

  test('throws descriptive error when passed successful ParseResult instead of AST', () => {
    const result = parse(validWireframe);

    // Verify we have a successful parse result
    expect(result.success).toBe(true);

    // This is the common mistake: passing result instead of result.ast
    expect(() => {
      render(result as unknown as AST);
    }).toThrow('render() expects an AST object, but received a ParseResult');

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('Did you forget to extract .ast?');
  });

  test('throws descriptive error when passed failed ParseResult', () => {
    // Invalid wireframe that will fail to parse
    const invalidWireframe = '+--incomplete';
    const result = parse(invalidWireframe);

    // This should be a failed parse
    expect(result.success).toBe(false);

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('render() received a failed ParseResult');

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('Check parse errors before calling render');
  });

  test('throws descriptive error when passed null or undefined', () => {
    expect(() => {
      render(null as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');

    expect(() => {
      render(undefined as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');
  });

  test('throws descriptive error when passed object without scenes array', () => {
    const invalidAST = { foo: 'bar' };

    expect(() => {
      render(invalidAST as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');

    expect(() => {
      render(invalidAST as unknown as AST);
    }).toThrow('Did you pass ParseResult instead of ParseResult.ast?');
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  // The renderer requires a browser or jsdom environment
  test.skip('works correctly when passed valid AST (requires DOM)', () => {
    const result = parse(validWireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      // This is the correct usage
      const { root, sceneManager } = render(result.ast);

      expect(root).toBeDefined();
      expect(root).toBeInstanceOf(HTMLElement);
      expect(sceneManager).toBeDefined();
      expect(sceneManager.getSceneIds()).toContain('test');
    }
  });
});

describe('createUI() convenience function', () => {
  test('handles parse errors gracefully', () => {
    const invalidWireframe = '+--incomplete';
    const result = createUI(invalidWireframe);

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.errors).toBeDefined();
      expect(result.errors.length).toBeGreaterThan(0);
    }
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  test.skip('works correctly with valid wireframe (requires DOM)', () => {
    const validWireframe = `
@scene: test

+-------+
| Hello |
+-------+
`;
    const result = createUI(validWireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.root).toBeDefined();
      expect(result.sceneManager).toBeDefined();
      expect(result.ast).toBeDefined();
    }
  });
});

describe('onSceneChange callback (Issue #2)', () => {
  const multiSceneWireframe = `
@scene: login

+---------------+
| Login Screen  |
+---------------+

---

@scene: dashboard

+---------------+
| Dashboard     |
+---------------+
`;

  test('OnSceneChangeCallback type is exported', () => {
    // Verify the type is exported by using it
    const callback: OnSceneChangeCallback = (_from, _to) => {};
    expect(typeof callback).toBe('function');
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  test.skip('render accepts onSceneChange option without throwing (requires DOM)', () => {
    const result = parse(multiSceneWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const callback = vi.fn();

      // This should not throw - just verify the API accepts the option
      expect(() => {
        render(result.ast, {
          onSceneChange: callback,
        });
      }).not.toThrow();
    }
  });

  test.skip('createUI accepts onSceneChange option without throwing (requires DOM)', () => {
    const callback = vi.fn();

    // Verify the API accepts the option
    expect(() => {
      createUI(multiSceneWireframe, {
        onSceneChange: callback,
      });
    }).not.toThrow();
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  test.skip('onSceneChange is called on initial scene load (requires DOM)', () => {
    const result = parse(multiSceneWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const callback = vi.fn();
      render(result.ast, { onSceneChange: callback });

      // Should be called once for initial scene
      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith(undefined, 'login');
    }
  });

  test.skip('onSceneChange is called when navigating between scenes (requires DOM)', () => {
    const result = parse(multiSceneWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const callback = vi.fn();
      const { sceneManager } = render(result.ast, { onSceneChange: callback });

      // Clear mock after initial call
      callback.mockClear();

      // Navigate to dashboard
      sceneManager.goto('dashboard');

      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith('login', 'dashboard');
    }
  });

  test.skip('onSceneChange is not called when navigating to the same scene (requires DOM)', () => {
    const result = parse(multiSceneWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const callback = vi.fn();
      const { sceneManager } = render(result.ast, { onSceneChange: callback });

      // Clear mock after initial call
      callback.mockClear();

      // Navigate to the same scene
      sceneManager.goto('login');

      expect(callback).not.toHaveBeenCalled();
    }
  });

  test.skip('onSceneChange receives correct fromScene and toScene values (requires DOM)', () => {
    const result = parse(multiSceneWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const navigationHistory: Array<{ from: string | undefined; to: string }> = [];
      const callback: OnSceneChangeCallback = (from, to) => {
        navigationHistory.push({ from, to });
      };

      const { sceneManager } = render(result.ast, { onSceneChange: callback });

      // Navigate through scenes
      sceneManager.goto('dashboard');
      sceneManager.goto('login');

      expect(navigationHistory).toEqual([
        { from: undefined, to: 'login' },  // Initial
        { from: 'login', to: 'dashboard' },
        { from: 'dashboard', to: 'login' },
      ]);
    }
  });
});

describe('device option override (Issue #11)', () => {
  const desktopWireframe = `
@scene: test
@device: desktop

+---------------+
| Desktop Scene |
+---------------+
`;

  test('DeviceType type is exported', () => {
    // Verify the type is exported by using it
    const device: DeviceType = 'mobile';
    expect(typeof device).toBe('string');
  });

  test('RenderOptions includes device field in type definition', () => {
    // Verify the device option is part of RenderOptions type
    const options: RenderOptions = {
      device: 'mobile',
    };
    expect(options.device).toBe('mobile');
  });

  test('RenderOptions accepts all valid device types', () => {
    const deviceTypes: DeviceType[] = [
      'desktop',
      'laptop',
      'tablet',
      'tablet-landscape',
      'mobile',
      'mobile-landscape',
    ];

    deviceTypes.forEach((deviceType) => {
      const options: RenderOptions = { device: deviceType };
      expect(options.device).toBe(deviceType);
    });
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  test.skip('render accepts device option without throwing (requires DOM)', () => {
    const result = parse(desktopWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      // This should not throw - just verify the API accepts the option
      expect(() => {
        render(result.ast, { device: 'mobile' });
      }).not.toThrow();
    }
  });

  test.skip('createUI accepts device option without throwing (requires DOM)', () => {
    // Verify the API accepts the option
    expect(() => {
      createUI(desktopWireframe, { device: 'tablet' });
    }).not.toThrow();
  });

  test.skip('device option overrides scene-defined device class (requires DOM)', () => {
    const result = parse(desktopWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      // Render with mobile override
      const { root } = render(result.ast, { device: 'mobile' });

      // Should have mobile class, not desktop
      expect(root.classList.contains('wf-device-mobile')).toBe(true);
      expect(root.classList.contains('wf-device-desktop')).toBe(false);
    }
  });

  test.skip('device option applies correct class for all device types (requires DOM)', () => {
    const result = parse(desktopWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      const deviceClassMap: Record<DeviceType, string> = {
        desktop: 'wf-device-desktop',
        laptop: 'wf-device-laptop',
        tablet: 'wf-device-tablet',
        'tablet-landscape': 'wf-device-tablet-landscape',
        mobile: 'wf-device-mobile',
        'mobile-landscape': 'wf-device-mobile-landscape',
      };

      Object.entries(deviceClassMap).forEach(([deviceType, expectedClass]) => {
        const { root } = render(result.ast, { device: deviceType as DeviceType });
        expect(root.classList.contains(expectedClass)).toBe(true);
      });
    }
  });

  test.skip('renders with scene device when no override provided (requires DOM)', () => {
    const result = parse(desktopWireframe);
    expect(result.success).toBe(true);

    if (result.success) {
      // Render without device override
      const { root } = render(result.ast);

      // Should use the scene-defined desktop device
      expect(root.classList.contains('wf-device-desktop')).toBe(true);
    }
  });
});
