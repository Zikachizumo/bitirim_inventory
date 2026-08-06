import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { SlotWithItem } from '../typings';

interface ContextMenuState {
  coords: {
    x: number;
    y: number;
  } | null;
  item: SlotWithItem | null;
  // Bitirim: karakter panelindeki GIYILI ekipman slotu icin (sag tik -> Unequip).
  // item null iken bu doluysa InventoryContext "Unequip" menusu gosterir.
  equipSlot: string | null;
}

const initialState: ContextMenuState = {
  coords: null,
  item: null,
  equipSlot: null,
};

export const contextMenuSlice = createSlice({
  name: 'contextMenu',
  initialState,
  reducers: {
    openContextMenu(
      state,
      action: PayloadAction<{ item?: SlotWithItem | null; equipSlot?: string | null; coords: { x: number; y: number } }>
    ) {
      state.coords = action.payload.coords;
      state.item = action.payload.item ?? null;
      state.equipSlot = action.payload.equipSlot ?? null;
    },
    closeContextMenu(state) {
      state.coords = null;
      state.equipSlot = null;
    },
  },
});

export const { openContextMenu, closeContextMenu } = contextMenuSlice.actions;

export default contextMenuSlice.reducer;
