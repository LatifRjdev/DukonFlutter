# Telegram Bot Setup for DuckonPro

## Step 1: Create Bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot`
3. Bot name: `DuckonPro Чеки`
4. Bot username: `duckonpro_receipts_bot` (must end with `_bot`)
5. BotFather gives you a token like: `7123456789:AAH...`

## Step 2: Configure Bot

Send these commands to BotFather:

```
/setdescription
```
Select your bot, then type:
```
Бот для отправки чеков из DuckonPro. Привяжите свой номер телефона для получения чеков автоматически.
```

```
/setabouttext
```
```
Официальный бот DuckonPro для получения электронных чеков
```

```
/setuserpic
```
Upload your app logo as the bot avatar.

## Step 3: Add Token to Backend

In `api/.env`:
```
TELEGRAM_BOT_TOKEN=7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Step 4: Set Webhook (after deploying backend)

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://api.duckonpro.tj/telegram/webhook"}'
```

Replace `<TOKEN>` with your actual bot token and the URL with your actual backend URL.

## Step 5: Test

1. Find your bot in Telegram: @duckonpro_receipts_bot
2. Send `/start`
3. Bot should reply asking for phone number
4. Share your contact
5. Bot confirms linking

## How Customers Use It

1. Customer opens Telegram, finds @duckonpro_receipts_bot
2. Presses "Start"
3. Shares their phone number (Telegram button)
4. Bot links their phone to the customer record in DuckonPro
5. After each sale, cashier can tap "Send to Telegram" on the receipt
