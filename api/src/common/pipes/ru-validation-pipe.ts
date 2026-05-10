import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { ValidationError } from 'class-validator';

/**
 * F1.2: class-validator emits English defaults like "name must be a string"
 * which then surface verbatim in the mobile app's Russian UI. This pipe
 * extends Nest's ValidationPipe with a translation layer that rewrites
 * the most common constraint messages into Russian.
 *
 * Custom per-DTO `{ message: '...' }` strings still win — the translator
 * only kicks in when the message matches a known English template.
 */
export class RuValidationPipe extends ValidationPipe {
  constructor() {
    super({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors: ValidationError[]) => {
        const messages = flatten(errors).map(translate);
        return new BadRequestException({
          statusCode: 400,
          message: messages,
        });
      },
    });
  }
}

function flatten(errors: ValidationError[], parent?: string): string[] {
  const out: string[] = [];
  for (const e of errors) {
    const path = parent ? `${parent}.${e.property}` : e.property;
    if (e.constraints) {
      for (const msg of Object.values(e.constraints)) {
        out.push(typeof msg === 'string' ? msg : JSON.stringify(msg));
      }
    }
    if (e.children?.length) {
      out.push(...flatten(e.children, path));
    }
  }
  return out;
}

/**
 * Translate well-known class-validator defaults to Russian. Custom
 * messages from the DTO already in Russian or in a domain-specific tone
 * fall through unchanged.
 */
export function translate(msg: string): string {
  // Exact-template substitutions, ordered by specificity.
  const rules: Array<[RegExp, (m: RegExpMatchArray) => string]> = [
    [
      /^property (.+) should not exist$/,
      (m) => `Поле «${m[1]}» не разрешено в этом запросе`,
    ],
    [/^(.+) must be a string$/, (m) => `Поле «${m[1]}» должно быть строкой`],
    [
      /^(.+) must be a number conforming to the specified constraints$/,
      (m) => `Поле «${m[1]}» должно быть числом`,
    ],
    [
      /^(.+) must be a boolean value$/,
      (m) => `Поле «${m[1]}» должно быть true или false`,
    ],
    [
      /^(.+) must be a valid ISO 8601 date string$/,
      (m) => `Поле «${m[1]}» должно быть датой в формате ISO 8601`,
    ],
    [/^(.+) must be an array$/, (m) => `Поле «${m[1]}» должно быть массивом`],
    [
      /^(.+) should not be empty$/,
      (m) => `Поле «${m[1]}» не должно быть пустым`,
    ],
    [
      /^(.+) must be longer than or equal to (\d+) characters?$/,
      (m) => `Поле «${m[1]}» должно содержать не менее ${m[2]} символов`,
    ],
    [
      /^(.+) must be shorter than or equal to (\d+) characters?$/,
      (m) => `Поле «${m[1]}» должно содержать не более ${m[2]} символов`,
    ],
    [
      /^Password must be at least (\d+) characters long$/,
      (m) => `Пароль должен содержать не менее ${m[1]} символов`,
    ],
    [
      /^(.+) must not be less than (-?\d+(?:\.\d+)?)$/,
      (m) => `Поле «${m[1]}» должно быть не меньше ${m[2]}`,
    ],
    [
      /^(.+) must not be greater than (-?\d+(?:\.\d+)?)$/,
      (m) => `Поле «${m[1]}» должно быть не больше ${m[2]}`,
    ],
    [
      /^(.+) must be one of the following values: (.+)$/,
      (m) => `Поле «${m[1]}» должно быть одним из: ${m[2]}`,
    ],
    [
      /^(.+) must be an email$/,
      (m) => `Поле «${m[1]}» должно быть корректным email`,
    ],
    [/^(.+) must be a UUID$/, (m) => `Поле «${m[1]}» должно быть UUID`],
    [
      /^Phone must be a valid Tajik number \(\+992XXXXXXXXX\)$/,
      () => 'Номер телефона должен быть в формате +992XXXXXXXXX',
    ],
  ];

  for (const [pattern, rewrite] of rules) {
    const m = msg.match(pattern);
    if (m) return rewrite(m);
  }
  return msg;
}
