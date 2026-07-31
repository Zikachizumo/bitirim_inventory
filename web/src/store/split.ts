import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';
import { SlotWithItem } from '../typings';

/**
 * Bitirim — "Divide" (yigin bolme) diyalogu durumu.
 * Sag tik menusunde Divide'a basilinca acilir; item + adet secilir.
 */
const initialState: { item: SlotWithItem | null } = { item: null };

export const splitSlice = createSlice({
  name: 'split',
  initialState,
  reducers: {
    openSplit: (state, action: PayloadAction<SlotWithItem>) => {
      state.item = action.payload;
    },
    closeSplit: (state) => {
      state.item = null;
    },
  },
});

export const { openSplit, closeSplit } = splitSlice.actions;
export const selectSplitItem = (state: RootState) => state.split.item;
export default splitSlice.reducer;
