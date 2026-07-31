import React from 'react';
import RightInventory from './RightInventory';
import CharacterStats from './CharacterStats';

/**
 * Bitirim — yere dusen item (drop) paneli.
 * Sol hucrede: 5x5 drop gridi (ust) + CAN/ZIRH/AÇLIK/SUSUZLUK statlari (alt).
 * Boylece drop acikken karakter statlari kaybolmaz (kullanici istegi).
 * Grid 5 sutun `.bx-drop` CSS'iyle; drop slot sayisi sunucuda 25 (init.lua).
 */
const DropPanel: React.FC = () => (
  <div className="bx-panel bx-drop">
    <RightInventory />
    <div className="bx-drop-stats">
      <CharacterStats />
    </div>
  </div>
);

export default DropPanel;
