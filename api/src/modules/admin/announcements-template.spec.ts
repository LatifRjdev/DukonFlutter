import { renderTemplate, AnnouncementVars } from './announcements-template';

const sampleVars: AnnouncementVars = {
  user: { name: 'Алишер', phone: '+992900111222' },
  store: {
    name: 'Магазин №1',
    currency: 'TJS',
    subscription: { plan: 'BUSINESS', currentPeriodEnd: '2026-06-15' },
  },
};

describe('renderTemplate', () => {
  it('substitutes a single placeholder', () => {
    expect(renderTemplate('Hello {{user.name}}', sampleVars)).toBe(
      'Hello Алишер',
    );
  });

  it('substitutes multiple placeholders', () => {
    expect(renderTemplate('{{user.name}} → {{store.name}}', sampleVars)).toBe(
      'Алишер → Магазин №1',
    );
  });

  it('walks nested paths', () => {
    expect(
      renderTemplate('Plan: {{store.subscription.plan}}', sampleVars),
    ).toBe('Plan: BUSINESS');
  });

  it('passes unknown placeholders through verbatim', () => {
    expect(renderTemplate('Hi {{user.email}}', sampleVars)).toBe(
      'Hi {{user.email}}',
    );
  });

  it('passes null / undefined leaves through verbatim', () => {
    const vars: any = { user: { name: null } };
    expect(renderTemplate('Hi {{user.name}}', vars)).toBe('Hi {{user.name}}');
  });

  it('handles a template with no placeholders', () => {
    expect(renderTemplate('plain text', sampleVars)).toBe('plain text');
  });

  it('does NOT recursively expand placeholders in substituted values', () => {
    const vars: any = { user: { name: '{{secret}}' }, secret: 'leaked' };
    expect(renderTemplate('Hi {{user.name}}', vars)).toBe('Hi {{secret}}');
  });

  it('coerces numeric values to string', () => {
    const vars: any = { count: 42 };
    expect(renderTemplate('You have {{count}} items', vars)).toBe(
      'You have 42 items',
    );
  });
});
