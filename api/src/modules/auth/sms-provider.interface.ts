export interface SmsProvider {
  sendSms(phone: string, message: string): Promise<void>;
}

export const SMS_PROVIDER = 'SMS_PROVIDER';
