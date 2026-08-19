import { createCipheriv, createDecipheriv, createHmac, randomBytes } from 'node:crypto';
import { environment } from '../config.js';

function encryptionKey(): Buffer {
  const configured = environment().FIELD_ENCRYPTION_KEY_CURRENT;
  return configured
    ? Buffer.from(configured, 'base64')
    : createHmac('sha256', environment().SESSION_SIGNING_KEY).update('fixture-encryption').digest();
}
export function encryptField(value: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [
    environment().FIELD_ENCRYPTION_KEY_VERSION,
    iv.toString('base64url'),
    tag.toString('base64url'),
    ciphertext.toString('base64url'),
  ].join('.');
}
export function decryptField(value: string): string {
  const parts = value.split('.');
  if (parts.length !== 4) throw new Error('invalid encrypted field');
  const iv = Buffer.from(parts[1] ?? '', 'base64url');
  const tag = Buffer.from(parts[2] ?? '', 'base64url');
  const ciphertext = Buffer.from(parts[3] ?? '', 'base64url');
  const decipher = createDecipheriv('aes-256-gcm', encryptionKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
}
export function hmacIndex(value: string): string {
  return createHmac('sha256', environment().HMAC_INDEX_KEY).update(value).digest('hex');
}
export function token(bytes = 32): string {
  return randomBytes(bytes).toString('base64url');
}
export function maskStudentId(value: string): string {
  return value.length <= 4
    ? '****'
    : `${value.slice(0, 2)}${'*'.repeat(value.length - 4)}${value.slice(-2)}`;
}
