import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import BitirimHints from './BitirimHints';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, selectRightInventory, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { setPlayerStatus, PlayerStatus } from '../../store/playerStatus';
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

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <div className="bx-window">
            <BitirimTopBar />

            <div className="bx-body">
              <div className="bx-col-side">
                {hasContainer ? (
                  <div className="bx-panel bx-container">
                    <RightInventory />
                  </div>
                ) : (
                  <CharacterPanel />
                )}
              </div>

              <div className="bx-col-main">
                <PlayerPanel />
              </div>

              <div className="bx-col-side">
                <BitirimHints />
              </div>

              <div className="bx-col-main">
                <GiveBar />
              </div>
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
