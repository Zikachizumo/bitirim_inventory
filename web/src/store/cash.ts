import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — nakit (cash).
 *
 * GrandRP mantigi: nakit ENVANTER ITEM'i DEGIL; qbx_core/account yonetir.
 * Client Lua `setCash` ile qbx nakit'ini yollar; ust bar bunu gosterir.
 */
const initialState: { amount: number } = { amount: 0 };

export const cashSlice = createSlice({
  name: 'cash',
  initialState,
  reducers: {
    setCash: (state, action: PayloadAction<number>) => {
      state.amount = Math.max(0, Math.floor(action.payload || 0));
    },
  },
});

export const { setCash } = cashSlice.actions;
export const selectCash = (state: RootState) => state.cash.amount;

export default cashSlice.reducer;
