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
    {/* Temiz baslik (plaka/ID + KG YOK). Envanter panelinin basligiyla ayni
        yukseklikte -> drop gridi ile envanter gridinin siralari hizali olur. */}
    <div className="bx-inv-head">
      <p className="bx-panel-title">Yere Atılanlar</p>
    </div>
    <RightInventory />
    <div className="bx-drop-stats">
      <CharacterStats />
    </div>
  </div>
);

export default DropPanel;
