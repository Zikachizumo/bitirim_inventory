import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — canta seviyesi (0-5).
 *
 * Seviye 0 = CANTASIZ: sadece 5 makro slotu kullanilir, tum grid kilitli.
 * Yeni oyuncu boyle baslar. 1-5 markette satin alma / kraft ile acilir.
 *
 * Her seviye: acik grid slotu, agirlik kapasitesi ve tema rengi belirler.
 * Renkler CSS'te :root[data-lv='0'..'5']; seviye degisince index.tsx
 * <html data-lv> yazar. Veri client Lua'dan `setBagLevel` ile gelir.
 */

export const BAG_LEVELS = 5;
export const SLOTS_PER_LEVEL = 7; // grid 7 sutun: her seviye 1 sira acar. L1=7 ... L5=35 (L0=0)
export const GRID_TOTAL = 35; // 7 sutun x 5 sira
// index = seviye. L0 (cantasiz) icin taban kapasite — degeri sonra ayarlanacak.
export const BAG_CAP_KG = [10, 20, 35, 50, 70, 90];

const initialState: { level: number } = { level: 0 };

export const backpackSlice = createSlice({
  name: 'backpack',
  initialState,
  reducers: {
    setBagLevel: (state, action: PayloadAction<number>) => {
      const n = Math.max(0, Math.min(BAG_LEVELS, Math.floor(action.payload || 0)));
      state.level = n;
    },
  },
});

export const { setBagLevel } = backpackSlice.actions;
export const selectBagLevel = (state: RootState) => state.backpack.level;

/** O seviyede acik grid slotu sayisi (0-based sinir: bu indexten itibaren kilitli).
 *  L0 -> 0 (hepsi kilitli), L5 -> 35 (hicbiri kilitli degil). */
export const unlockedGridSlots = (level: number) => Math.max(0, Math.min(GRID_TOTAL, level * SLOTS_PER_LEVEL));

export default backpackSlice.reducer;
