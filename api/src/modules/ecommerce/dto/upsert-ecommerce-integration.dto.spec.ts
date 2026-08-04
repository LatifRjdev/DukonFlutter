import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpsertEcommerceIntegrationDto } from './upsert-ecommerce-integration.dto';

async function validateDto(plain: Record<string, unknown>) {
  const dto = plainToInstance(UpsertEcommerceIntegrationDto, plain);
  return validate(dto);
}

// Whole-branch review flagged that outboundWebhookUrl only carried
// @IsUrl({ require_tld: false }), which happily accepts
// http://169.254.169.254/... (cloud metadata endpoint), http://localhost,
// or any other private-IP-literal target. EcommerceOutboundService.
// postWithRetry does a bare server-side fetch(url, ...) against whatever is
// configured — combined with Fix 2's guard, this is real SSRF surface.
// IsSafeWebhookUrl (common/validators/safe-webhook-url.validator.ts) closes
// it at write time.
describe('UpsertEcommerceIntegrationDto validation — outboundWebhookUrl SSRF hardening', () => {
  it('accepts a normal public https webhook URL', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'https://merchant-site.example.com/webhook',
    });
    expect(errors).toHaveLength(0);
  });

  it('accepts null (clearing a previously-configured webhook)', async () => {
    const errors = await validateDto({ outboundWebhookUrl: null });
    expect(errors).toHaveLength(0);
  });

  it('accepts the field being omitted entirely', async () => {
    const errors = await validateDto({});
    expect(errors).toHaveLength(0);
  });

  it('rejects localhost', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://localhost:3000/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects the cloud metadata link-local address', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://169.254.169.254/latest/meta-data',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects a 10.0.0.0/8 private IP literal', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://10.1.2.3/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects a 192.168.0.0/16 private IP literal', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://192.168.1.1/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects a 172.16.0.0/12 private IP literal', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://172.16.5.5/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects the IPv6 loopback address', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'http://[::1]/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects a non-http(s) scheme', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'ftp://merchant-site.example.com/webhook',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });

  it('rejects the file scheme', async () => {
    const errors = await validateDto({
      outboundWebhookUrl: 'file:///etc/passwd',
    });
    expect(errors.some((e) => e.property === 'outboundWebhookUrl')).toBe(true);
  });
});
