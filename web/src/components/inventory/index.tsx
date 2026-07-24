import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import BitirimHints from './BitirimHints';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, selectRightInventory, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { setPlayerStatus, PlayerStatus } from '../../store/playerStatus';
import { setEquippedSlot } from '../../store/equipment';
import { setBagLevel } from '../../store/backpack';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';
import BitirimTopBar from './BitirimTopBar';
import CharacterPanel from './CharacterPanel';
import PlayerPanel from './PlayerPanel';
import GiveBar from './GiveBar';

/**
 * Bitirim envanter penceresi.
 *
 * Yerlesim (onaylanmis mockup):
 *   ust bar
 *   sol sutun : Karakter paneli — bir kap acikken yerini o kap alir (A secenegi)
 *   sag sutun : oyuncunun envanteri (grid + dikey makro sutunu + canta karti)
 *   alt satir : kullanim talimatlari + "Surukle & Ver" bari
 *
 * Eski InventoryControl (adet/Use/Give/Close) kaldirildi; yerine kullanim
 * talimatlari (BitirimHints) kondu. Kaldirmak guvenli: sunucu ver/al/at
 * miktarini math.max(1,...) ile kirpiyor, yarim bolme SHIFT ile calisiyor.
 */
const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch = useAppDispatch();
  const rightInventory = useAppSelector(selectRightInventory);

  // Bir kap (stash / bagaj / market / yer) acik mi? Acik degilken id bos string.
  const hasContainer = !!rightInventory.id;

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  // Bitirim: karakter panelindeki durum barlari (client Lua'dan gercek veri)
  useNuiEvent<PlayerStatus>('setPlayerStatus', (data) => dispatch(setPlayerStatus(data)));

  // Bitirim: o an kusanili slot (sag tik menusunde Use/Unequip etiketi icin)
  useNuiEvent<number | null>('setEquippedSlot', (data) => dispatch(setEquippedSlot(data)));

  // Bitirim: canta seviyesi -> tema rengi (<html data-lv>) + acik/kilitli slotlar
  useNuiEvent<number>('setBagLevel', (level) => {
    dispatch(setBagLevel(level));
    document.documentElement.dataset.lv = String(Math.max(0, Math.min(5, Math.floor(level || 0))));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <div className="bx-window">
            <BitirimTopBar />

            {/* 2x2 grid: satir1 = ana kutular (esit yukseklik),
                satir2 = alt barlar (esit yukseklik). align-items:stretch her
                hucreyi satir yuksekligine ceker. */}
            <div className="bx-body">
              {hasContainer ? (
                <div className="bx-panel bx-container">
                  <RightInventory />
                </div>
              ) : (
                <CharacterPanel />
              )}
              <PlayerPanel />
              <BitirimHints />
              <GiveBar />
            </div>
          </div>

          <Tooltip />
          <InventoryContext />
        </div>
      </Fade>
      <InventoryHotbar />
    </>
  );
};

export default Inventory;
