import { beforeEach, describe, expect, it, vi } from 'vitest';
import { storage } from './storage';

const values = new Map<string, unknown>();
let failPrivacyWrite = false;

beforeEach(() => {
  values.clear();
  failPrivacyWrite = false;
  vi.stubGlobal('wx', {
    getStorageSync: (key: string) => values.get(key) ?? '',
    setStorageSync: (key: string, value: unknown) => {
      if (key === 'privacy_consent_v1' && failPrivacyWrite) {
        failPrivacyWrite = false;
        throw new Error('storage full');
      }
      values.set(key, value);
    },
    removeStorageSync: (key: string) => void values.delete(key),
  } as unknown as typeof wx);
});

describe('consented session storage', () => {
  it('stores the consent version and session together', () => {
    storage.saveConsentedSession('2026-08-24', 'access-new', 'refresh-new');

    expect(values.get('session_access_v1')).toBe('access-new');
    expect(values.get('session_refresh_v1')).toBe('refresh-new');
    expect(values.get('privacy_consent_v1')).toBe('2026-08-24');
  });

  it('restores the previous state when a write fails', () => {
    values.set('session_access_v1', 'access-old');
    values.set('session_refresh_v1', 'refresh-old');
    values.set('privacy_consent_v1', '2026-08-18');
    failPrivacyWrite = true;

    expect(() => storage.saveConsentedSession('2026-08-24', 'access-new', 'refresh-new')).toThrow(
      'storage full',
    );
    expect(values.get('session_access_v1')).toBe('access-old');
    expect(values.get('session_refresh_v1')).toBe('refresh-old');
    expect(values.get('privacy_consent_v1')).toBe('2026-08-18');
  });
});
