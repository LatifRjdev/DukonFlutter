import {
  incrementCounter,
  readCounter,
  runWithCounter,
} from '../../../src/common/prisma/query-counter.context';

describe('query-counter context', () => {
  it('starts at 0 inside runWithCounter', async () => {
    await runWithCounter({ count: 0, endpoint: 'test' }, async () => {
      const store = readCounter();
      expect(store?.count).toBe(0);
    });
  });

  it('incrementCounter increments inside the context', async () => {
    await runWithCounter({ count: 0, endpoint: 'test' }, async () => {
      incrementCounter();
      incrementCounter();
      incrementCounter();
      expect(readCounter()?.count).toBe(3);
    });
  });

  it('two parallel runs have independent counters', async () => {
    const p1 = runWithCounter({ count: 0, endpoint: 'a' }, async () => {
      incrementCounter();
      await new Promise((r) => setImmediate(r));
      incrementCounter();
      return readCounter()?.count;
    });
    const p2 = runWithCounter({ count: 0, endpoint: 'b' }, async () => {
      incrementCounter();
      await new Promise((r) => setImmediate(r));
      return readCounter()?.count;
    });
    const [c1, c2] = await Promise.all([p1, p2]);
    expect(c1).toBe(2);
    expect(c2).toBe(1);
  });

  it('incrementCounter is a no-op outside context', () => {
    expect(() => incrementCounter()).not.toThrow();
    expect(readCounter()).toBeUndefined();
  });
});
