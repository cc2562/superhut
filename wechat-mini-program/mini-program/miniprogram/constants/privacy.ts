export const PRIVACY_CONSENT_VERSION = '2026-08-24.1';

export function hasAcceptedCurrentPrivacy(savedVersion: string): boolean {
  return savedVersion === PRIVACY_CONSENT_VERSION;
}
