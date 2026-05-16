// api/src/modules/admin/announcements-template.ts
//
// Spec C: pure template helper for {{path.to.field}} substitution
// in admin announcements. Single-pass (no recursive expansion to
// prevent injection from substituted values). No new dep.
export interface AnnouncementVars {
  user: { name: string; phone: string };
  store: {
    name: string;
    currency: string;
    subscription: { plan: string; currentPeriodEnd: string };
  };
}

/**
 * Substitutes `{{path.to.field}}` placeholders in `template` with
 * values from `vars`. Single-pass (no recursive expansion).
 * Unknown placeholders pass through verbatim.
 */
export function renderTemplate(
  template: string,
  vars: Record<string, unknown> | AnnouncementVars,
): string {
  return template.replace(/\{\{([\w.]+)\}\}/g, (match, path: string) => {
    const value = path
      .split('.')
      .reduce<unknown>(
        (acc, key) =>
          acc && typeof acc === 'object'
            ? (acc as Record<string, unknown>)[key]
            : undefined,
        vars,
      );
    if (value === undefined || value === null) return match;
    return String(value);
  });
}
