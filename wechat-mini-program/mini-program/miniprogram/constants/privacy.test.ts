import { describe, expect, it } from 'vitest';
import { hasAcceptedCurrentPrivacy, PRIVACY_CONSENT_VERSION } from './privacy';

describe('privacy consent version', () => {
  it('accepts only the current version', () => {
    expect(hasAcceptedCurrentPrivacy(PRIVACY_CONSENT_VERSION)).toBe(true);
    expect(hasAcceptedCurrentPrivacy('2026-08-24')).toBe(false);
    expect(hasAcceptedCurrentPrivacy('2026-08-18')).toBe(false);
    expect(hasAcceptedCurrentPrivacy('')).toBe(false);
  });
});
