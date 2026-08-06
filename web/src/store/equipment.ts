import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — ekipman durumu (TEK KAYNAK).
 *
 * İki parça:
 *  - `equippedSlot`: o an kuşanılı SİLAH slotu (client Lua getCurrentWeapon'i
 *    izleyip `setEquippedSlot` gönderir). Sağ tık menüsünde "Use" yerine
 *    "Unequip" yazmak için kullanılır.
 *  - `equipment`: karakter panelindeki GİYİLİ kıyafet/ekipman slotları
 *    (slot -> { drawable, texture }). Server (equipment_server.lua) DB'den
 *    üretir, client `setEquipment` ile gönderir. Bu veri hem paneli doldurur
 *    hem ileride 3D önizlemeyi besleyecek — dünya karakteri ile AYNI kaynak.
 */

export interface EquipItem {
  item?: string;
  // Görünüm (drawable/texture) client Lua'da cinsiyete göre çözülür; panel yalnız
  // `item`'i kullanır (görsel/etiket). Bu alanlar opsiyoneldir.
  drawable?: number;
  texture?: number;
}

export type EquipmentMap = Record<string, EquipItem>;

interface EquipmentState {
  equippedSlot: number | null;
  equipment: EquipmentMap;
}

const initialState: EquipmentState = { equippedSlot: null, equipment: {} };

export const equipmentSlice = createSlice({
  name: 'equipment',
  initialState,
  reducers: {
    setEquippedSlot: (state, action: PayloadAction<number | null>) => {
      state.equippedSlot = action.payload ?? null;
    },
    setEquipment: (state, action: PayloadAction<EquipmentMap | null | undefined>) => {
      state.equipment = action.payload ?? {};
    },
  },
});

export const { setEquippedSlot, setEquipment } = equipmentSlice.actions;
export const selectEquippedSlot = (state: RootState) => state.equipment.equippedSlot;
export const selectEquipment = (state: RootState) => state.equipment.equipment;
export default equipmentSlice.reducer;
