import { scrubEventPii } from './scrub-pii';

describe('scrubEventPii', () => {
  it('redacts password and phone in request.data', () => {
    const event: any = {
      request: { data: { phone: '+992900111222', password: 'secret123' } },
    };
    scrubEventPii(event);
    expect(event.request.data.password).toBe('[Filtered]');
    expect(event.request.data.phone).toBe('[Filtered]');
  });

  it('redacts token-like fields in extra', () => {
    const event: any = {
      extra: { accessToken: 'eyJhbG...', refreshToken: 'xyz', other: 'keep' },
    };
    scrubEventPii(event);
    expect(event.extra.accessToken).toBe('[Filtered]');
    expect(event.extra.refreshToken).toBe('[Filtered]');
    expect(event.extra.other).toBe('keep');
  });

  it('walks nested objects', () => {
    const event: any = {
      request: { data: { nested: { password: 'p', ok: 'v' } } },
    };
    scrubEventPii(event);
    expect(event.request.data.nested.password).toBe('[Filtered]');
    expect(event.request.data.nested.ok).toBe('v');
  });

  it('redacts Authorization header (case-insensitive)', () => {
    const event: any = {
      request: { headers: { Authorization: 'Bearer xxx', 'X-Other': 'y' } },
    };
    scrubEventPii(event);
    expect(event.request.headers.Authorization).toBe('[Filtered]');
    expect(event.request.headers['X-Other']).toBe('y');
  });

  it('no-ops on event without request/extra', () => {
    const event: any = { message: 'hello' };
    expect(() => scrubEventPii(event)).not.toThrow();
    expect(event.message).toBe('hello');
  });
});
