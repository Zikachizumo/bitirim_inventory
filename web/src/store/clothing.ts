import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — karakterin uzerindeki kiyafet/aksesuarlar.
 *
 * Anahtar = karakter panelindeki equip slotu ('jacket', 'pants', 'glasses'...).
 * Veri client Lua'dan gelir (modules/bitirim/clothing.lua -> setWornClothing);
 * arayuz kendi basina "giyili" karari VERMEZ, yalnizca gosterir.
 *
 * Gorsel item'in kendi metadata.imageurl'idir: magazadan alinan parca envanterde
 * hangi ikonla duruyorsa panelde de o gorunur.
 */

export interface WornPiece {
  /** Item ikonunun tam URL'i (nui://bitirim_clothing/web/images/...png). */
  image?: string;
  /** Kategori etiketi ('Torso', 'Pant'...) — tooltip'te gosterilir. */
  label?: string;
  drawable?: number;
  texture?: number;
  /** Parcanin durdugu envanter slotu (yalnizca bilgi). */
  slot?: number;
}

export type WornClothing = Record<string, WornPiece>;

const initialState: { worn: WornClothing } = { worn: {} };

export const clothingSlice = createSlice({
  name: 'clothing',
  initialState,
  reducers: {
    setWornClothing: (state, action: PayloadAction<WornClothing | unknown[] | null | undefined>) => {
      const data = action.payload;
      // Lua bos tabloyu JSON DIZISI olarak serilestirir; o durumda "hicbir sey
      // giyili degil" demektir.
      state.worn = !data || Array.isArray(data) ? {} : (data as WornClothing);
    },
  },
});

export const { setWornClothing } = clothingSlice.actions;
export const selectWornClothing = (state: RootState) => state.clothing.worn;
export default clothingSlice.reducer;
