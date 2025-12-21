/**
 * Sample test file to verify Jest configuration
 *
 * This file tests basic JavaScript functionality and verifies
 * that Jest is properly configured for the Wyreframe parser project.
 */

describe('Setup Test Suite', () => {
  test('addition works correctly', () => {
    expect(1 + 2).toBe(3);
  });

  test('string concatenation works', () => {
    expect('Hello' + ' ' + 'World').toBe('Hello World');
  });

  test('array operations work', () => {
    const arr = [1, 2, 3];
    expect(arr.length).toBe(3);
  });

  test('object creation works', () => {
    const obj = { name: 'test', value: 100 };
    expect(obj.name).toBe('test');
    expect(obj.value).toBe(100);
  });
});

describe('Parser Setup Verification', () => {
  test('Jest is configured correctly', () => {
    // This test verifies that Jest can run tests
    expect(true).toBe(true);
  });

  test('async/await support', async () => {
    const promise = Promise.resolve(42);
    const result = await promise;
    expect(result).toBe(42);
  });

  test('matcher assertions work', () => {
    expect([1, 2, 3]).toHaveLength(3);
    expect({ a: 1, b: 2 }).toHaveProperty('a');
    expect('hello').toMatch(/llo/);
  });
});

describe('ReScript Integration Readiness', () => {
  test('can import ES modules', () => {
    // Verify ES module support is working
    expect(typeof import).toBe('function');
  });

  test('test environment is configured', () => {
    expect(process.env.NODE_ENV).toBeDefined();
  });
});
