import 'reflect-metadata';
import { translate } from './ru-validation-pipe';

describe('translate (RU validation messages)', () => {
  test.each([
    [
      'name must be a string',
      'Поле «name» должно быть строкой',
    ],
    [
      'sellPrice must be a number conforming to the specified constraints',
      'Поле «sellPrice» должно быть числом',
    ],
    [
      'name should not be empty',
      'Поле «name» не должно быть пустым',
    ],
    [
      'name must be shorter than or equal to 80 characters',
      'Поле «name» должно содержать не более 80 символов',
    ],
    [
      'Password must be at least 8 characters long',
      'Пароль должен содержать не менее 8 символов',
    ],
    [
      'sellPrice must not be less than 0',
      'Поле «sellPrice» должно быть не меньше 0',
    ],
    [
      'unit must be one of the following values: PCS, KG, L, M, PACK',
      'Поле «unit» должно быть одним из: PCS, KG, L, M, PACK',
    ],
    [
      'property startDate should not exist',
      'Поле «startDate» не разрешено в этом запросе',
    ],
    [
      'email must be an email',
      'Поле «email» должно быть корректным email',
    ],
    [
      'birthday must be a valid ISO 8601 date string',
      'Поле «birthday» должно быть датой в формате ISO 8601',
    ],
    [
      'Phone must be a valid Tajik number (+992XXXXXXXXX)',
      'Номер телефона должен быть в формате +992XXXXXXXXX',
    ],
  ])('%s -> %s', (input, expected) => {
    expect(translate(input)).toBe(expected);
  });

  test('falls through unchanged when no rule matches', () => {
    const custom =
      'Custom domain message that is not a class-validator default';
    expect(translate(custom)).toBe(custom);
  });

  test('falls through unchanged for already-Russian messages', () => {
    const ru = 'Поле «name» обязательно';
    expect(translate(ru)).toBe(ru);
  });
});
