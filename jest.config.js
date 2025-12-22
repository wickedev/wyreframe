export default {
  // Use jsdom environment for DOM testing
  testEnvironment: 'node',

  // Test file patterns
  // ReScript compiles .res files to .mjs, so we test the compiled output
  testMatch: [
    '**/__tests__/**/*.test.mjs',
    '**/__tests__/**/*.test.js',
    '**/*.test.mjs',
    '**/*.test.js'
  ],

  // Ignore ReScript source files in test discovery (test the compiled .mjs instead)
  testPathIgnorePatterns: [
    '/node_modules/',
    '\\.res$'
  ],

  // Module file extensions
  moduleFileExtensions: ['js', 'mjs', 'res'],

  // Transform ReScript compiled files (*.mjs)
  transform: {},

  // Coverage configuration
  collectCoverageFrom: [
    'src/**/*.{js,mjs}',
    '!src/**/*.test.{js,mjs}',
    '!src/**/__tests__/**',
    '!**/node_modules/**'
  ],

  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    }
  },

  // Coverage reporters
  coverageReporters: ['text', 'lcov', 'html'],

  // Verbose output
  verbose: true,

  // Clear mocks between tests
  clearMocks: true,
};
