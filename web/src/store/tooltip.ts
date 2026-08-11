import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { Inventory, SlotWithItem } from '../typings';

// Tooltip artik HOVER ile degil, item'e TEK SOL TIK ile acilir; slot dikdortgenine
// sabitlenir (coords = slotun getBoundingClientRect'i). Mouse takibi YOK.
export interface TooltipCoords {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface TooltipState {
  open: boolean;
  item: SlotWithItem | null;
  inventoryType: Inventory['type'] | null;
  coords: TooltipCoords | null;
}

const initialState: TooltipState = {
  open: false,
  item: null,
  inventoryType: null,
  coords: null,
};

type OpenPayload = { item: SlotWithItem; inventoryType: Inventory['type']; coords: TooltipCoords };

export const tooltipSlice = createSlice({
  name: 'tooltip',
  initialState,
  reducers: {
    openTooltip(state, action: PayloadAction<OpenPayload>) {
      state.open = true;
      state.item = action.payload.item;
      state.inventoryType = action.payload.inventoryType;
      state.coords = action.payload.coords;
    },
    // Ayni item'e tekrar tiklayinca kapat; farkli item'e / kapaliyken tiklayinca ac.
    toggleTooltip(state, action: PayloadAction<OpenPayload>) {
      const { item, inventoryType, coords } = action.payload;
      const sameItem = state.open && state.item?.slot === item.slot && state.inventoryType === inventoryType;
      if (sameItem) {
        state.open = false;
        return;
      }
      state.open = true;
      state.item = item;
      state.inventoryType = inventoryType;
      state.coords = coords;
    },
    closeTooltip(state) {
      state.open = false;
    },
  },
});

export const { openTooltip, toggleTooltip, closeTooltip } = tooltipSlice.actions;

export default tooltipSlice.reducer;
