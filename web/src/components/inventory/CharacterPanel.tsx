import React from 'react';
import { useAppSelector } from '../../store';
import { selectPlayerStatus } from '../../store/playerStatus';
import {
  IconAmmo,
  IconBackpack,
  IconCap,
  IconDrop,
  IconFood,
  IconGlasses,
  IconGloves,
  IconHeadphones,
  IconHeart,
  IconJacket,
  IconMask,
  IconNecklace,
  IconPants,
  IconPistol,
  IconRing,
  IconShield,
  IconShoes,
  IconTshirt,
  IconVest,
  IconWatch,
} from './BitirimIcons';

/**
 * Bitirim karakter paneli.
 *
 * DURUM: ekipman slotlari su an GORSEL — giyme/cikarma mantigi
 * (illenium-appearance koprusu) henuz baglanmadi. Slotlar bos gorunur,
 * bu dogru: gercekten hicbir sey kusanilmis degil.
 *
 * Statlar yalnizca client Lua'dan gercek veri geldiginde gosterilir.
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

const Stat: React.FC<{ kind: string; label: string; value: number; Icon: React.FC<{ size?: number }> }> = ({
  kind,
  label,
  value,
  Icon,
}) => (
  <div className={`bx-stat bx-stat-${kind}`}>
    <div className="bx-stat-top">
      <Icon size={18} />
      <span className="bx-stat-label">{label}</span>
      <span className="bx-stat-pct">{Math.round(value)}%</span>
    </div>
    <div className="bx-bar">
      <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </div>
  </div>
);

const CharacterPanel: React.FC = () => {
  const status = useAppSelector(selectPlayerStatus);

  return (
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

      {/* Alt bolge: statlar dikeyde ortalanir. Karsi panelde (envanter) canta
          karti da ayni sekilde ortalanir -> ikisinin ortasi hizali olur. */}
      <div className="bx-char-bottom">
        {status && (
          <div className="bx-stats">
            <Stat kind="can" label="Can" value={status.health} Icon={IconHeart} />
            <Stat kind="zirh" label="Zırh" value={status.armour} Icon={IconShield} />
            {status.hunger !== undefined && (
              <Stat kind="aclik" label="Açlık" value={status.hunger} Icon={IconFood} />
            )}
            {status.thirst !== undefined && (
              <Stat kind="susuzluk" label="Susuzluk" value={status.thirst} Icon={IconDrop} />
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default CharacterPanel;
