import type { Timetable } from '@superhut/api-contract';

const keys = {
  access: 'session_access_v1',
  refresh: 'session_refresh_v1',
  timetable: 'timetable_snapshot_v1',
  privacy: 'privacy_consent_v1',
  credential: 'academic_credentials_v1',
  mode: 'timetable_mode_v1',
} as const;
export interface TimetableCache {
  value: Timetable;
  fetchedAt: string;
}
type TimetableCacheMap = Record<string, TimetableCache>;
interface SavedCredential {
  schemaVersion: 1;
  studentId: string;
  password: string;
  savedAt: string;
  expiresAt: string;
}

export const storage = {
  accessToken: () => wx.getStorageSync<string>(keys.access) || '',
  refreshToken: () => wx.getStorageSync<string>(keys.refresh) || '',
  saveSession: (accessToken: string, refreshToken: string) => {
    wx.setStorageSync(keys.access, accessToken);
    wx.setStorageSync(keys.refresh, refreshToken);
  },
  clearSession: () => {
    wx.removeStorageSync(keys.access);
    wx.removeStorageSync(keys.refresh);
  },
  privacyAccepted: () => wx.getStorageSync<string>(keys.privacy) || '',
  acceptPrivacy: (version: string) => wx.setStorageSync(keys.privacy, version),
  timetable: (semesterId: string) => {
    const all = wx.getStorageSync<TimetableCacheMap>(keys.timetable) || {};
    return all[semesterId] || null;
  },
  latestTimetable: (): TimetableCache | null => {
    const all = wx.getStorageSync<TimetableCacheMap>(keys.timetable) || {};
    const entries = Object.values(all);
    if (!entries.length) return null;
    return entries.reduce((latest, current) =>
      Date.parse(current.fetchedAt) > Date.parse(latest.fetchedAt) ? current : latest,
    );
  },
  saveTimetable: (value: Timetable, fetchedAt: string) => {
    const all = wx.getStorageSync<TimetableCacheMap>(keys.timetable) || {};
    all[value.semesterId] = { value, fetchedAt };
    wx.setStorageSync(keys.timetable, all);
  },
  clearTimetable: () => wx.removeStorageSync(keys.timetable),
  mode: (): 'week' | 'day' => (wx.getStorageSync<string>(keys.mode) === 'day' ? 'day' : 'week'),
  saveMode: (mode: 'week' | 'day') => wx.setStorageSync(keys.mode, mode),
  async saveCredential(studentId: string, password: string): Promise<void> {
    const savedAt = new Date();
    const expiresAt = new Date(savedAt.getTime() + 30 * 24 * 60 * 60 * 1000);
    const data: SavedCredential = {
      schemaVersion: 1,
      studentId,
      password,
      savedAt: savedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
    };
    await wx.setStorage({ key: keys.credential, data, encrypt: true });
  },
  async credential(): Promise<SavedCredential | null> {
    try {
      const getEncryptedStorage = wx.getStorage as unknown as (options: {
        key: string;
        encrypt: true;
      }) => Promise<WechatMiniprogram.GetStorageSuccessCallbackResult<SavedCredential>>;
      const result = await getEncryptedStorage({ key: keys.credential, encrypt: true });
      if (result.data.schemaVersion !== 1 || Date.parse(result.data.expiresAt) <= Date.now()) {
        await storage.deleteCredential();
        return null;
      }
      return result.data;
    } catch {
      return null;
    }
  },
  async deleteCredential(): Promise<void> {
    try {
      await wx.removeStorage({ key: keys.credential });
    } catch {
      /* already absent */
    }
  },
  async clearAll(): Promise<void> {
    await storage.deleteCredential();
    storage.clearSession();
    storage.clearTimetable();
    wx.removeStorageSync(keys.privacy);
    wx.removeStorageSync(keys.mode);
  },
};
