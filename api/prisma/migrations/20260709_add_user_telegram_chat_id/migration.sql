-- Migration: add telegramChatId to User for store owner Telegram notifications
ALTER TABLE "users" ADD COLUMN "telegramChatId" TEXT;
