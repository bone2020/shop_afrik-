/** Tests run inside `firebase emulators:exec` (see the `test` script). */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.test.json' }],
  },
  // One emulator shared by every file: run serially so clears don't race.
  maxWorkers: 1,
  testTimeout: 20000,
};
