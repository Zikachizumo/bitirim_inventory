import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — canta seviyesi (1-5).
 *
 * Her seviye: acik grid slotu, agirlik kapasitesi ve tema rengi belirler.
 * Renkler CSS'te :root[data-lv='1'..'5'] olarak hazir; seviye degisince
 * index.tsx <html data-lv> yazar.
 *
 * Veri client Lua'dan `setBagLevel` NUI mesajiyla gelir.
 */

export const BAG_LEVELS = 5;
export const SLOTS_PER_LEVEL = 8; // grid: L1=8 ... L5=40
export const BAG_CAP_KG = [0, 20, 35, 50, 70, 90]; // 1..5 (index 0 kullanilmaz)

const initialState: { level: number } = { level: 1 };

export const backpackSlice = createSlice({
  name: 'backpack',
  initialState,
  reducers: {
    setBagLevel: (state, action: PayloadAction<number>) => {
      const n = Math.max(1, Math.min(BAG_LEVELS, Math.floor(action.payload || 1)));
      state.level = n;
    },
  },
});

export const { setBagLevel } = backpackSlice.actions;
export const selectBagLevel = (state: RootState) => state.backpack.level;

/** O seviyede acik grid slotu sayisi (0-based sinir: bu indexten itibaren kilitli). */
export const unlockedGridSlots = (level: number) => Math.min(40, level * SLOTS_PER_LEVEL);

export default backpackSlice.reducer;
