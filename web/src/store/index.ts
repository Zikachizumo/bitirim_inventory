import { Action, configureStore, ThunkAction } from '@reduxjs/toolkit';
import { TypedUseSelectorHook, useDispatch, useSelector } from 'react-redux';
import inventoryReducer from './inventory';
import tooltipReducer from './tooltip';
import contextMenuReducer from './contextMenu';
import playerStatusReducer from './playerStatus';
import equipmentReducer from './equipment';
import clothingReducer from './clothing';
import backpackReducer from './backpack';
import splitReducer from './split';
import cashReducer from './cash';

export const store = configureStore({
  reducer: {
    inventory: inventoryReducer,
    tooltip: tooltipReducer,
    contextMenu: contextMenuReducer,
    playerStatus: playerStatusReducer,
    equipment: equipmentReducer,
    clothing: clothingReducer,
    backpack: backpackReducer,
    split: splitReducer,
    cash: cashReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
export type RootState = ReturnType<typeof store.getState>;
export type AppThunk<ReturnType = void> = ThunkAction<ReturnType, RootState, unknown, Action<string>>;

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
