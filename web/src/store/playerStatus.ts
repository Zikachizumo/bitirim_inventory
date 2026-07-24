import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — karakter panelindeki durum barlari (CAN / ZIRH / ACLIK / SUSUZLUK).
 *
 * Veri client Lua tarafindan `setPlayerStatus` NUI mesajiyla gelir
 * (modules/bitirim/client.lua). Veri gelmeden once `null` kalir ve panel
 * durum bloğunu hic gostermez — uydurma deger gosterilmez.
 */
export type PlayerStatus = {
  health: number; // 0-100
  armour: number; // 0-100
  hunger?: number; // 0-100 (framework saglamazsa yok)
  thirst?: number; // 0-100
};

const initialState: { status: PlayerStatus | null } = { status: null };

export const playerStatusSlice = createSlice({
  name: 'playerStatus',
  initialState,
  reducers: {
    setPlayerStatus: (state, action: PayloadAction<PlayerStatus>) => {
      state.status = action.payload;
    },
  },
});

export const { setPlayerStatus } = playerStatusSlice.actions;
export const selectPlayerStatus = (state: RootState) => state.playerStatus.status;
export default playerStatusSlice.reducer;
