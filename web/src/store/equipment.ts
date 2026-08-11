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

export interface EquipWear {
  slot?: string;
  drawable?: number;
  texture?: number;
  male?: { drawable: number; texture: number };
  female?: { drawable: number; texture: number };
}

export interface EquipItem {
  item?: string; // base item adı ('apparel' veya legacy named item)
  label?: string; // metadata.label — panelde gösterilen ad
  image?: string; // metadata.image — web/images/<image>.png
  // Görünüm client Lua'da cinsiyete göre çözülür; panel `wear`'ı kullanmaz.
  wear?: EquipWear;
}

export type EquipmentMap = Record<string, EquipItem>;

// Kuşanılı silah (client Lua getCurrentWeapon'dan). Karakter panelindeki SİLAH
// slotunda gösterilir. `false`/null = silah yok (kılıçta/holstered).
export interface EquippedWeapon {
  name?: string;
  label?: string;
  slot?: number;
}

// Legacy named kıyafet item'i -> hedef slot haritası (itemName -> slotKey). apparel
// item'leri slotu metadata.wear.slot'ta taşır; legacy item'ler (ör. 'armour') taşımaz,
// bu yüzden sürükle-giy highlight'ı için client Lua (data.bitirim_clothing) bunu yollar.
export type ClothingMap = Record<string, string>;

interface EquipmentState {
  equippedSlot: number | null;
  equippedWeapon: EquippedWeapon | null;
  equipment: EquipmentMap;
  clothingMap: ClothingMap;
  // Envanterde giyilebilir bir item'e tiklaninca (tooltip acilinca) o item'in HEDEF
  // karakter slotu -> panelde parlar ("bu item buraya giyilir" ipucu). null = yok.
  highlightSlot: string | null;
}

const initialState: EquipmentState = {
  equippedSlot: null,
  equippedWeapon: null,
  equipment: {},
  clothingMap: {},
  highlightSlot: null,
};

export const equipmentSlice = createSlice({
  name: 'equipment',
  initialState,
  reducers: {
    setEquippedSlot: (state, action: PayloadAction<number | null>) => {
      state.equippedSlot = action.payload ?? null;
    },
    setEquippedWeapon: (state, action: PayloadAction<EquippedWeapon | false | null | undefined>) => {
      state.equippedWeapon = action.payload || null;
    },
    setEquipment: (state, action: PayloadAction<EquipmentMap | null | undefined>) => {
      state.equipment = action.payload ?? {};
    },
    setClothingMap: (state, action: PayloadAction<ClothingMap | null | undefined>) => {
      state.clothingMap = action.payload ?? {};
    },
    setHighlightSlot: (state, action: PayloadAction<string | null | undefined>) => {
      state.highlightSlot = action.payload ?? null;
    },
  },
});

export const { setEquippedSlot, setEquippedWeapon, setEquipment, setClothingMap, setHighlightSlot } =
  equipmentSlice.actions;
export const selectEquippedSlot = (state: RootState) => state.equipment.equippedSlot;
export const selectEquippedWeapon = (state: RootState) => state.equipment.equippedWeapon;
export const selectEquipment = (state: RootState) => state.equipment.equipment;
export const selectClothingMap = (state: RootState) => state.equipment.clothingMap;
export const selectHighlightSlot = (state: RootState) => state.equipment.highlightSlot;
export default equipmentSlice.reducer;
