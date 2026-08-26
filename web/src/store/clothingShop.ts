import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

/**
 * Bitirim — kıyafet mağazası (GrandRP tarzı kategori + sepet akışı).
 *
 * Katalog (categories/items) Lua tarafından (data/bitirim_clothing_shop.lua)
 * `setShopVisible` NUI olayıyla gelir — tek kaynak, burada ELLE tanımlanmaz.
 * Sepet (cart) tamamen client-side state; checkout'ta olduğu gibi server'a
 * yollanır (`bitirim:clothingCheckout` → server-authoritative fiyat/stok
 * doğrulaması `clothing_shop_server.lua`'da yapılır).
 */

export interface ShopWear {
  drawable: number;
  texture: number;
}

export interface ShopCategory {
  id: string;
  label: string;
  icon: string;
}

export interface ShopItem {
  id: string;
  category: string;
  label: string;
  price: number;
  slot: string;
  male?: ShopWear;
  female?: ShopWear;
}

export interface CartLine {
  id: string;
  qty: number;
}

type ShopView = 'categories' | 'grid';

interface ClothingShopState {
  visible: boolean;
  categories: ShopCategory[];
  items: ShopItem[];
  view: ShopView;
  selectedCategory: string | null;
  selectedItem: string | null;
  quantity: number;
  cart: CartLine[];
  cartOpen: boolean;
}

const initialState: ClothingShopState = {
  visible: false,
  categories: [],
  items: [],
  view: 'categories',
  selectedCategory: null,
  selectedItem: null,
  quantity: 1,
  cart: [],
  cartOpen: false,
};

export const clothingShopSlice = createSlice({
  name: 'clothingShop',
  initialState,
  reducers: {
    setShopVisible: (
      state,
      action: PayloadAction<{ visible: boolean; catalog?: { categories: ShopCategory[]; items: ShopItem[] } }>
    ) => {
      state.visible = action.payload.visible;
      if (action.payload.catalog) {
        state.categories = action.payload.catalog.categories || [];
        state.items = action.payload.catalog.items || [];
      }
      if (!action.payload.visible) {
        // Kapanınca gezinme/sepet durumunu sıfırla (bir sonraki açılış temiz başlasın).
        state.view = 'categories';
        state.selectedCategory = null;
        state.selectedItem = null;
        state.quantity = 1;
        state.cart = [];
        state.cartOpen = false;
      }
    },
    openCategory: (state, action: PayloadAction<string>) => {
      state.selectedCategory = action.payload;
      state.view = 'grid';
      state.selectedItem = null;
      state.quantity = 1;
    },
    backToCategories: (state) => {
      state.view = 'categories';
      state.selectedCategory = null;
      state.selectedItem = null;
      state.quantity = 1;
    },
    selectItem: (state, action: PayloadAction<string>) => {
      state.selectedItem = action.payload;
      state.quantity = 1;
    },
    setQuantity: (state, action: PayloadAction<number>) => {
      state.quantity = Math.max(1, Math.floor(action.payload || 1));
    },
    addToCart: (state, action: PayloadAction<{ id: string; qty: number }>) => {
      const existing = state.cart.find((line) => line.id === action.payload.id);
      if (existing) {
        existing.qty += action.payload.qty;
      } else {
        state.cart.push({ id: action.payload.id, qty: action.payload.qty });
      }
    },
    removeFromCart: (state, action: PayloadAction<string>) => {
      state.cart = state.cart.filter((line) => line.id !== action.payload);
    },
    clearCart: (state) => {
      state.cart = [];
    },
    toggleCart: (state) => {
      state.cartOpen = !state.cartOpen;
    },
  },
});

export const {
  setShopVisible,
  openCategory,
  backToCategories,
  selectItem,
  setQuantity,
  addToCart,
  removeFromCart,
  clearCart,
  toggleCart,
} = clothingShopSlice.actions;

export const selectShopVisible = (state: RootState) => state.clothingShop.visible;
export const selectShopCategories = (state: RootState) => state.clothingShop.categories;
export const selectShopItems = (state: RootState) => state.clothingShop.items;
export const selectShopView = (state: RootState) => state.clothingShop.view;
export const selectShopSelectedCategory = (state: RootState) => state.clothingShop.selectedCategory;
export const selectShopSelectedItem = (state: RootState) => state.clothingShop.selectedItem;
export const selectShopQuantity = (state: RootState) => state.clothingShop.quantity;
export const selectShopCart = (state: RootState) => state.clothingShop.cart;
export const selectShopCartOpen = (state: RootState) => state.clothingShop.cartOpen;

export default clothingShopSlice.reducer;
