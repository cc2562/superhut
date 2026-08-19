import { describe, expect, it } from 'vitest';
import { decryptField, encryptField, hmacIndex, maskStudentId } from '../src/common/security.js';

describe('sensitive field handling', () => {
  it('encrypts values with authenticated encryption', () => {
    const value = 'sensitive-fixture-value';
    const ciphertext = encryptField(value);
    expect(ciphertext).not.toContain(value);
    expect(decryptField(ciphertext)).toBe(value);
  });
  it('uses keyed non-reversible indexes and masks student ids', () => {
    expect(hmacIndex('2300000001')).toHaveLength(64);
    expect(maskStudentId('2300000001')).toBe('23******01');
  });
});
