import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — o an kusanili/giyili slot.
 *
 * Su an yalnizca silah icin dolar (client Lua getCurrentWeapon'i izleyip
 * `setEquippedSlot` gonderir). Kiyafet giyme sistemi baglaninca ayni slice
 * giyili kiyafet slotlari icin de kullanilabilir.
 *
 * Sag tik menusunde bu slot icin "Use" yerine "Unequip" yazilir.
 */
const initialState: { equippedSlot: number | null } = { equippedSlot: null };

export const equipmentSlice = createSlice({
  name: 'equipment',
  initialState,
  reducers: {
    setEquippedSlot: (state, action: PayloadAction<number | null>) => {
      state.equippedSlot = action.payload ?? null;
    },
  },
});

export const { setEquippedSlot } = equipmentSlice.actions;
export const selectEquippedSlot = (state: RootState) => state.equipment.equippedSlot;
export default equipmentSlice.reducer;
