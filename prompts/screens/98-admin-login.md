Создай веб-страницу (Desktop, 1440x900px) для входа в админ-панель платформы "DuckonPro Admin". Стиль: современный, чистый, профессиональный. Центрированная форма.

Дизайн-система: Primary #00BCD4, Success #4CAF50, Danger #F44336, Background #0F172A (тёмный), Cards #FFFFFF, Text #1E293B, Text Secondary #64748B. Шрифт Inter. Радиус карточек 16px, inputs 12px, кнопок 12px. Иконки Outlined (Lucide).

## Вход в админ-панель

- Фон: тёмный gradient (#0F172A → #1E293B), полноэкранный
- Декоративный паттерн: лёгкие полупрозрачные геометрические линии на фоне (grid/dots, opacity 5%)

- По центру экрана — белая карточка (420px ширина, padding 40px, радиус 16px, тень 0 8px 32px rgba(0,0,0,0.2)):
  - Логотип "DuckonPro" (бирюзовый, 32px Bold) + текст "Admin Panel" (16px, серый #64748B) — по центру
  - Отступ 32px
  - "Вход в систему" (20px SemiBold, по центру)
  - Отступ 24px
  - Поле "Email *" — input (outlined, радиус 12px, иконка mail слева, placeholder "admin@dokonpro.com")
  - Отступ 16px
  - Поле "Пароль *" — input (outlined, type password, иконка lock слева, иконка eye справа для показа, placeholder "••••••••")
  - Отступ 16px
  - Поле "Код 2FA" — input (outlined, 6 цифр, иконка shield слева, placeholder "000000") + подсказка "Введите код из Google Authenticator" (12px, серый)
  - Отступ 8px
  - Checkbox + "Запомнить меня" (слева) + ссылка "Забыли пароль?" (справа, бирюзовый, 14px)
  - Отступ 24px
  - Кнопка "Войти" (бирюзовая #00BCD4, на всю ширину, 48px высота, 16px текст, Bold, белый, радиус 12px, hover: #00ACC1)
  - Отступ 24px
  - Разделитель с текстом "или"
  - Отступ 16px
  - Кнопка "Войти через Google" (outlined, серая рамка, иконка Google слева, на всю ширину)

- Под карточкой: "DuckonPro Admin v1.0" (12px, белый opacity 50%) + "© 2026 ITL Solutions" (12px, белый opacity 30%)
