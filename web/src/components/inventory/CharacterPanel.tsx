import React from 'react';
import CharacterStats from './CharacterStats';
import { useAppSelector } from '../../store';
import { selectBagLevel } from '../../store/backpack';
import { selectWornClothing } from '../../store/clothing';
import { getItemUrl } from '../../helpers';
import { fetchNui } from '../../utils/fetchNui';
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
 *
 * ÇANTA slotu (key='bag') takili canta seviyesine gore bag_lvN.png gosterir.
 *
 * KIYAFET/AKSESUAR slotlari (jacket, tshirt, pants, shoes, gloves, armour,
 * mask, necklace, glasses, ears, watch, bracelet, hat) karakterin uzerinde ne
 * varsa onu gosterir. Veriyi client Lua uretir
 * (modules/bitirim/clothing.lua -> setWornClothing); burasi yalnizca cizer.
 * Anahtarlar o dosyadaki COMPONENT_SLOT / PROP_SLOT ile BIREBIR ayni olmali.
 *
 * Dolu bir kiyafet slotuna tiklamak parcayi cikarir (component'ler underwear
 * tabanina duser, prop'lar tamamen kaldirilir).
 */

const EQUIP_ROWS: { key: string; label: string; Icon: React.FC<{ size?: number }> }[][] = [
  [
    { key: 'hat', label: 'Şapka', Icon: IconCap },
    { key: 'glasses', label: 'Gözlük', Icon: IconGlasses },
    { key: 'ears', label: 'Kulaklık', Icon: IconHeadphones },
    { key: 'mask', label: 'Maske', Icon: IconMask },
  ],
  [
    // GTA'da parmak takisi yok; bu slot magazadaki Bracelet (prop 7) icindir.
    { key: 'bracelet', label: 'Bileklik', Icon: IconRing },
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
  const worn = useAppSelector(selectWornClothing);
  let slotNo = 0; // tum slotlara sirali numara (1..N)

  return (
    <div className="bx-panel bx-character">
      <p className="bx-panel-title">Karakter</p>

      <div className="bx-eq-grid">
        {EQUIP_ROWS.map((row, i) => (
          <div className="bx-eq-row" key={`eqrow-${i}`}>
            {row.map(({ key, label, Icon }) => {
              slotNo += 1;

              // Canta slotu: takili seviyeye gore gercek gorsel (bag_lvN.png).
              // Diger slotlar: karakterin uzerindeki parcanin item ikonu.
              const piece = key !== 'bag' ? worn[key] : undefined;
              const url =
                key === 'bag'
                  ? bagLevel > 0
                    ? getItemUrl(`bag_lv${bagLevel}`)
                    : undefined
                  : piece?.image;

              const title =
                key === 'bag'
                  ? bagLevel > 0
                    ? `Çanta — Seviye ${bagLevel}`
                    : 'Çanta — boş'
                  : piece
                    ? `${piece.label || label} — çıkarmak için tıkla`
                    : `${label} — boş`;

              return (
                <div
                  className={url ? 'bx-eq-slot has-item' : 'bx-eq-slot'}
                  key={key}
                  title={title}
                  role={piece ? 'button' : undefined}
                  onClick={piece ? () => fetchNui('bitirimUnequipClothing', { key }) : undefined}
                  style={url ? { backgroundImage: `url(${url})` } : undefined}
                >
                  <span className="bx-eq-num">{slotNo}</span>
                  {!url && <Icon size={32} />}
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
