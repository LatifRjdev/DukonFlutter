import '@testing-library/jest-dom/vitest';
import { afterAll, afterEach, beforeAll, vi } from 'vitest';
import { cleanup } from '@testing-library/react';
import { server } from './msw/server';

// Test JWT secret used by middleware tests.
process.env.JWT_ACCESS_SECRET = 'test-jwt-secret-do-not-use-in-prod';

// Allow tests to call /api/* relative paths.
process.env.NEXT_PUBLIC_API_URL = 'http://api.test/api';

// jsdom 29 ships an experimental localStorage implementation that requires
// `--localstorage-file`. Replace it with a simple in-memory store so tests can
// call setItem/getItem/clear without flags.
if (typeof window !== 'undefined') {
  const memStore = new Map<string, string>();
  const storage: Storage = {
    get length() {
      return memStore.size;
    },
    clear: () => memStore.clear(),
    getItem: (k: string) => (memStore.has(k) ? (memStore.get(k) as string) : null),
    key: (i: number) => Array.from(memStore.keys())[i] ?? null,
    removeItem: (k: string) => {
      memStore.delete(k);
    },
    setItem: (k: string, v: string) => {
      memStore.set(k, String(v));
    },
  };
  Object.defineProperty(window, 'localStorage', {
    configurable: true,
    value: storage,
  });
}

// Stub matchMedia for components that read it during render.
if (typeof window !== 'undefined' && !window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  });
}

beforeAll(() => server.listen({ onUnhandledRequest: 'bypass' }));
afterEach(() => {
  server.resetHandlers();
  cleanup();
});
afterAll(() => server.close());
