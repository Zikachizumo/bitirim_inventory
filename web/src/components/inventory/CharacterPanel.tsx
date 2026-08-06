import React from 'react';
import CharacterStats from './CharacterStats';
import { useAppSelector } from '../../store';
import { selectBagLevel } from '../../store/backpack';
import { selectEquipment } from '../../store/equipment';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { getItemUrl } from '../../helpers';
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
 * Slotlar NUMARALI (sag ustte kucuk rozet) — karisiklik olmasin diye.
 * ÇANTA slotu (key='bag') GERCEK: takili canta seviyesine gore bag_lvN.png
 * gorselini gosterir; seviye degisince (use ile giyme/yukseltme) otomatik
 * guncellenir. Diger slotlar su an GORSEL (illenium-appearance koprusu ileride).
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

const CharacterPanel: React.FC = () => {
  const bagLevel = useAppSelector(selectBagLevel);
  const equipment = useAppSelector(selectEquipment);
  let slotNo = 0; // tum slotlara sirali numara (1..N)

  // Dolu bir ekipman slotuna tiklayinca cikar (item envantere doner).
  const handleUnequip = (slot: string) => {
    fetchNui('bitirim:unequip', { slot }).catch(() => {});
  };

  return (
    <div className="bx-panel bx-character">
      <p className="bx-panel-title">Karakter</p>

      <div className="bx-eq-grid">
        {EQUIP_ROWS.map((row, i) => (
          <div className="bx-eq-row" key={`eqrow-${i}`}>
            {row.map(({ key, label, Icon }) => {
              slotNo += 1;

              // Canta slotu: takili seviyeye gore gercek gorsel (bag_lvN.png) — AYRI sistem.
              if (key === 'bag') {
                const bagUrl = bagLevel > 0 ? getItemUrl(`bag_lv${bagLevel}`) : undefined;
                return (
                  <div
                    className={bagUrl ? 'bx-eq-slot has-item' : 'bx-eq-slot'}
                    key={key}
                    title={bagLevel > 0 ? `Çanta — Seviye ${bagLevel}` : 'Çanta — boş'}
                    style={bagUrl ? { backgroundImage: `url(${bagUrl})` } : undefined}
                  >
                    <span className="bx-eq-num">{slotNo}</span>
                    {!bagUrl && <Icon size={32} />}
                  </div>
                );
              }

              // Kiyafet/ekipman slotu: giyiliyse item gorseli (varsa) + tikla-cikar.
              // Item gorseli yoksa (art henuz eklenmedi) accent highlight + kategori
              // ikonu ile "giyili" belli olur.
              const equipped = equipment[key];
              const equippedName = equipped?.item;
              const equipImage = equippedName ? Items[equippedName]?.image : undefined;
              const equipUrl = equipImage ? getItemUrl(equippedName as string) : undefined;
              const equipLabel = equippedName ? Items[equippedName]?.label || equippedName : undefined;
              const title = equipped ? `${equipLabel ?? label} — çıkarmak için tıkla` : `${label} — boş`;

              return (
                <div
                  className={equipped ? 'bx-eq-slot has-item' : 'bx-eq-slot'}
                  key={key}
                  title={title}
                  onClick={equipped ? () => handleUnequip(key) : undefined}
                  style={{
                    ...(equipUrl ? { backgroundImage: `url(${equipUrl})` } : undefined),
                    cursor: equipped ? 'pointer' : undefined,
                  }}
                >
                  <span className="bx-eq-num">{slotNo}</span>
                  {!equipUrl && <Icon size={32} />}
                </div>
              );
            })}
          </div>
        ))}
      </div>

      {/* Alt bolge: statlar dikeyde ortalanir (karsi paneldeki canta kartiyla hizali). */}
      <div className="bx-char-bottom">
        <CharacterStats />
      </div>
    </div>
  );
};

export default CharacterPanel;
