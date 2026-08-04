import {
  registerDecorator,
  ValidationArguments,
  ValidationOptions,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

// SSRF hardening for merchant-supplied webhook URLs. EcommerceOutboundService
// does a bare server-side `fetch(url, ...)` against whatever a merchant
// configures as outboundWebhookUrl — without this check, a merchant (or
// anyone with store.manage access) could point the webhook at
// 169.254.169.254 (cloud metadata endpoint), localhost, or any other
// private/internal address and use Dukon's server as a network probe.
//
// Deliberately lightweight: this is a literal-hostname/IP blocklist, not a
// DNS-rebinding-proof solution. A hostname that only resolves to a private
// IP at request time (rather than being one literally) is not caught here
// — that would require resolving DNS at validation time and again at
// fetch time, which is out of scope for this fix.

const PRIVATE_IPV4_RANGES: ReadonlyArray<{
  base: [number, number, number, number];
  maskBits: number;
}> = [
  { base: [10, 0, 0, 0], maskBits: 8 }, // 10.0.0.0/8
  { base: [172, 16, 0, 0], maskBits: 12 }, // 172.16.0.0/12
  { base: [192, 168, 0, 0], maskBits: 16 }, // 192.168.0.0/16
  { base: [169, 254, 0, 0], maskBits: 16 }, // 169.254.0.0/16 (link-local, incl. cloud metadata)
  { base: [127, 0, 0, 0], maskBits: 8 }, // 127.0.0.0/8 (loopback)
  { base: [0, 0, 0, 0], maskBits: 8 }, // 0.0.0.0/8 ("this network")
];

function ipv4ToInt(parts: number[]): number {
  return (
    ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0
  );
}

function isPrivateIPv4(hostname: string): boolean {
  const match = hostname.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!match) return false;
  const parts = match.slice(1, 5).map(Number);
  if (parts.some((p) => p > 255)) return false;

  const target = ipv4ToInt(parts);
  return PRIVATE_IPV4_RANGES.some(({ base, maskBits }) => {
    const baseInt = ipv4ToInt(base);
    const mask = maskBits === 0 ? 0 : (0xffffffff << (32 - maskBits)) >>> 0;
    return (target & mask) === (baseInt & mask);
  });
}

function isPrivateOrLoopbackIPv6(hostname: string): boolean {
  const normalized = hostname.toLowerCase();
  if (normalized === '::1' || normalized === '::') return true;
  // Unique local (fc00::/7) and link-local (fe80::/10) address prefixes.
  if (/^fe80:/.test(normalized)) return true;
  if (/^f[cd][0-9a-f]{2}:/.test(normalized)) return true;
  return false;
}

function isDisallowedHost(hostname: string): boolean {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (normalized === 'localhost' || normalized.endsWith('.localhost')) {
    return true;
  }
  if (isPrivateIPv4(normalized)) return true;
  if (isPrivateOrLoopbackIPv6(normalized)) return true;
  return false;
}

@ValidatorConstraint({ name: 'isSafeWebhookUrl', async: false })
export class IsSafeWebhookUrlConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    if (value == null) return true; // optional/nullable fields handled elsewhere
    if (typeof value !== 'string') return false;

    let parsed: URL;
    try {
      parsed = new URL(value);
    } catch {
      return false;
    }

    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }

    return !isDisallowedHost(parsed.hostname);
  }

  defaultMessage(args: ValidationArguments): string {
    return `${args.property} must be a public http(s) URL — loopback, link-local, and private-network addresses are not allowed`;
  }
}

/**
 * Rejects webhook/callback URLs that target loopback, link-local, or
 * private-IP-literal hosts, or use a non-http(s) scheme. Attach to any
 * merchant-supplied URL that this server will later `fetch()` server-side
 * (SSRF surface).
 */
export function IsSafeWebhookUrl(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: IsSafeWebhookUrlConstraint,
    });
  };
}
