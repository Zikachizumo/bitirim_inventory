import React from 'react';
import CharacterStats from './CharacterStats';
import {
  IconAmmo,
  IconBackpack,
  IconCap,
  IconGlasses,
  IconGloves,
  IconHeadphones,
  IconJacket,
  IconMask,
  IconNecklace,
  IconPants,
  IconPistol,
  IconRing,
  IconShoes,
  IconTshirt,
  IconVest,
  IconWatch,
} from './BitirimIcons';

/**
 * Bitirim karakter paneli.
 *
 * DURUM: ekipman slotlari su an GORSEL — giyme/cikarma mantigi
 * (illenium-appearance koprusu) henuz baglanmadi.
 */

const EQUIP_ROWS: { key: string; label: string; Icon: React.FC<{ size?: number }> }[][] = [
  [
    { key: 'hat', label: 'Şapka', Icon: IconCap },
    { key: 'glasses', label: 'Gözlük', Icon: IconGlasses },
    { key: 'ears', label: 'Kulaklık', Icon: IconHeadphones },
    { key: 'mask', label: 'Maske', Icon: IconMask },
  ],
  [
    { key: 'ring', label: 'Yüzük', Icon: IconRing },
    { key: 'necklace', label: 'Kolye', Icon: IconNecklace },
    { key: 'watch', label: 'Saat', Icon: IconWatch },
  ],
  [
    { key: 'jacket', label: 'Ceket', Icon: IconJacket },
    { key: 'tshirt', label: 'Tişört', Icon: IconTshirt },
    { key: 'gloves', label: 'Eldiven', Icon: IconGloves },
    { key: 'armour', label: 'Zırh', Icon: IconVest },
    { key: 'bag', label: 'Çanta', Icon: IconBackpack },
  ],
  [
    { key: 'pants', label: 'Pantolon', Icon: IconPants },
    { key: 'shoes', label: 'Ayakkabı', Icon: IconShoes },
  ],
  [
    { key: 'weapon', label: 'Silah', Icon: IconPistol },
    { key: 'ammo', label: 'Mermi', Icon: IconAmmo },
  ],
];

const CharacterPanel: React.FC = () => (
  <div className="bx-panel bx-character">
    <p className="bx-panel-title">Karakter</p>

    <div className="bx-eq-grid">
      {EQUIP_ROWS.map((row, i) => (
        <div className="bx-eq-row" key={`eqrow-${i}`}>
          {row.map(({ key, label, Icon }) => (
            <div className="bx-eq-slot" key={key} title={`${label} — boş`}>
              <Icon size={32} />
            </div>
          ))}
        </div>
      ))}
    </div>

    {/* Alt bolge: statlar dikeyde ortalanir (karsi paneldeki canta kartiyla hizali). */}
    <div className="bx-char-bottom">
      <CharacterStats />
    </div>
  </div>
);

export default CharacterPanel;
