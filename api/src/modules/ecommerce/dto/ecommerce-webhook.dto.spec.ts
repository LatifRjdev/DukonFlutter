import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { EcommerceWebhookDto } from './ecommerce-webhook.dto';

function validPayload(overrides: Record<string, unknown> = {}) {
  return {
    event: 'order.created',
    externalOrderId: 'site-order-1',
    items: [{ externalProductId: 'sku-1', quantity: 2, price: 150 }],
    customer: {
      name: 'Иван Иванов',
      phone: '+992900000000',
      address: 'ул. Рудаки 1',
    },
    totalAmount: 300,
    ...overrides,
  };
}

async function validateDto(plain: Record<string, unknown>) {
  const dto = plainToInstance(EcommerceWebhookDto, plain);
  return validate(dto);
}

describe('EcommerceWebhookDto validation', () => {
  it('produces no errors for a well-formed order.created payload', async () => {
    const errors = await validateDto(validPayload());
    expect(errors).toHaveLength(0);
  });

  it('produces no errors for a well-formed order.cancelled payload', async () => {
    const errors = await validateDto({
      event: 'order.cancelled',
      externalOrderId: 'site-order-1',
    });
    expect(errors).toHaveLength(0);
  });

  // Regression for the crash the code-quality review caught: ValidateNested
  // alone is a no-op when the property is entirely absent, so an
  // order.created payload that simply omits `customer` (guest checkout,
  // minimal retry, etc.) previously passed validation with zero errors and
  // then blew up with a raw TypeError on dto.customer!.phone deep inside
  // EcommerceOrdersService's transaction, instead of the clean 422 + owner
  // notification every other rejection path produces.
  it('rejects an order.created payload with customer omitted entirely', async () => {
    const payload = validPayload();
    delete (payload as Record<string, unknown>).customer;

    const errors = await validateDto(payload);

    expect(errors.length).toBeGreaterThan(0);
    expect(errors.some((e) => e.property === 'customer')).toBe(true);
  });

  // Regression: items: [] previously passed IsArray with zero errors,
  // letting createOrder's missing-mapping/stock checks silently no-op on
  // an empty array and create a phantom COMPLETED sale with no line items.
  it('rejects an order.created payload with an empty items array', async () => {
    const errors = await validateDto(validPayload({ items: [] }));

    expect(errors.length).toBeGreaterThan(0);
    expect(errors.some((e) => e.property === 'items')).toBe(true);
  });

  // Regression: an unnormalized phone (missing the +992 prefix) would
  // otherwise create a different Customer record than the same person's
  // in-store purchases, since createOrder() upserts on [storeId, phone].
  it('rejects a customer phone that is missing the +992 prefix', async () => {
    const errors = await validateDto(
      validPayload({
        customer: {
          name: 'Иван Иванов',
          phone: '900000000',
          address: 'ул. Рудаки 1',
        },
      }),
    );

    expect(errors.length).toBeGreaterThan(0);
    const customerError = errors.find((e) => e.property === 'customer');
    expect(customerError).toBeDefined();
    const nestedPhoneError = customerError?.children?.find(
      (c) => c.property === 'phone',
    );
    expect(nestedPhoneError).toBeDefined();
  });

  it('should reject an item price with more than 2 decimal places', async () => {
    const errors = await validateDto(
      validPayload({
        items: [{ externalProductId: 'sku-1', quantity: 2, price: 19.999 }],
      }),
    );
    expect(errors).not.toHaveLength(0);
  });

  it('should accept an item price with exactly 2 decimal places', async () => {
    const errors = await validateDto(
      validPayload({
        items: [{ externalProductId: 'sku-1', quantity: 2, price: 19.99 }],
      }),
    );
    expect(errors).toHaveLength(0);
  });
});
