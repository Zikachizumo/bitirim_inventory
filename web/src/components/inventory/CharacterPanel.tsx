import React, { useCallback } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import CharacterStats from './CharacterStats';
import { useAppSelector } from '../../store';
import { selectBagLevel } from '../../store/backpack';
import { selectEquipment, EquipItem } from '../../store/equipment';
import { selectLeftInventory } from '../../store/inventory';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { getItemUrl } from '../../helpers';
import { DragSource, Slot } from '../../typings';
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

// Kiyafet olmayan slotlar: canta (ayri seviye sistemi), silah/mermi (ox weapon).
// Bunlarda surukle-giy/cikar YOK.
const NON_CLOTHING = new Set(['bag', 'weapon', 'ammo']);

interface EquipSlotProps {
  slotKey: string;
  label: string;
  Icon: React.FC<{ size?: number }>;
  slotNo: number;
  equipped?: EquipItem;
  onUnequip: (slot: string) => void;
  canEquipHere: (slotKey: string, source: DragSource) => boolean;
  onEquipDrop: (slotKey: string, source: DragSource) => void;
}

/**
 * Tek ekipman slotu. Kiyafet slotlari icin:
 *  - DROP hedefi (envanterden 'SLOT' surukle): dogru slota birakilinca giydirir.
 *  - DRAG kaynagi ('EQUIP'): giyili parcayi envantere surukleyip cikarmak icin
 *    (InventorySlot 'EQUIP' drop'unu unequip'e baglar).
 *  - Tik: giyiliyse cikar.
 */
const EquipSlot: React.FC<EquipSlotProps> = ({
  slotKey,
  label,
  Icon,
  slotNo,
  equipped,
  onUnequip,
  canEquipHere,
  onEquipDrop,
}) => {
  const isClothingSlot = !NON_CLOTHING.has(slotKey);

  const equippedName = equipped?.item;
  const equipImageName = equipped?.image || (equippedName ? Items[equippedName]?.image : undefined);
  const equipUrl = equipImageName ? getItemUrl(equipImageName) : undefined;
  const equipLabel = equipped?.label || (equippedName ? Items[equippedName]?.label || equippedName : undefined);

  // DRAG kaynagi ('EQUIP'): unequip icin `slot`; DragPreview icin `item`+`image`
  // (imlecte giyili parca kutusu gorunur, envanter surukleme ile ayni his).
  const [{ isDragging }, drag] = useDrag<
    { slot: string; item: { name?: string; slot: string }; image?: string },
    void,
    { isDragging: boolean }
  >(
    () => ({
      type: 'EQUIP',
      item: {
        slot: slotKey,
        item: { name: equippedName, slot: slotKey },
        image: equipUrl ? `url(${equipUrl})` : undefined,
      },
      canDrag: () => isClothingSlot && !!equipped,
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
    }),
    [slotKey, equipped, equippedName, equipUrl, isClothingSlot]
  );

  // DROP hedefi ('SLOT'): uyumlu kiyafet suruklenirken `canDrop` true olur (bu slot
  // ustunde OLMASA bile) -> uygun slot vurgulanir. `isOver` uzerine gelince guclenir.
  const [{ isOver, canDrop }, drop] = useDrop<DragSource, void, { isOver: boolean; canDrop: boolean }>(
    () => ({
      accept: 'SLOT',
      canDrop: (source) => isClothingSlot && canEquipHere(slotKey, source),
      drop: (source) => onEquipDrop(slotKey, source),
      collect: (monitor) => ({ isOver: monitor.isOver(), canDrop: monitor.canDrop() }),
    }),
    [slotKey, isClothingSlot, canEquipHere, onEquipDrop]
  );

  const connectRef = (el: HTMLDivElement | null) => {
    drag(drop(el));
  };

  const title = equipped
    ? `${equipLabel ?? label} — çıkarmak için tıkla veya envantere sürükle`
    : isClothingSlot
      ? `${label} — envanterden sürükleyip bırak`
      : `${label} — boş`;

  return (
    <div
      ref={connectRef}
      className={
        'bx-eq-slot' +
        (equipped ? ' has-item' : '') +
        (canDrop ? ' bx-eq-droppable' : '') +
        (isOver && canDrop ? ' bx-eq-dropover' : '')
      }
      title={title}
      onClick={equipped ? () => onUnequip(slotKey) : undefined}
      style={{
        ...(equipUrl ? { backgroundImage: `url(${equipUrl})` } : undefined),
        cursor: equipped ? 'pointer' : undefined,
        opacity: isDragging ? 0.4 : 1,
      }}
    >
      <span className="bx-eq-num">{slotNo}</span>
      {!equipUrl && <Icon size={32} />}
    </div>
  );
};

const CharacterPanel: React.FC = () => {
  const bagLevel = useAppSelector(selectBagLevel);
  const equipment = useAppSelector(selectEquipment);
  const leftInventory = useAppSelector(selectLeftInventory);
  let slotNo = 0; // tum slotlara sirali numara (1..N)

  // Dolu bir ekipman slotuna tiklayinca (veya envantere surukleyince) cikar.
  const handleUnequip = useCallback((slot: string) => {
    fetchNui('bitirim:unequip', { slot }).catch(() => {});
  }, []);

  // Suruklenen envanter item'ini Redux'tan bul (slot 1-indexli -> items[slot-1]).
  const sourceItem = useCallback(
    (source: DragSource): Slot | undefined => leftInventory.items?.[source.item.slot - 1],
    [leftInventory]
  );

  // Bu slota birakilabilir mi? Yalniz OYUNCU envanterinden gelen, kiyafet item'i
  // VE metadata.wear.slot bu slota esitse (dogru yere birak). Sadece dogru slot vurgulanir.
  const canEquipHere = useCallback(
    (slotKey: string, source: DragSource) => {
      if (source.inventory !== 'player') return false;
      const src = sourceItem(source) as any;
      return src?.metadata?.wear?.slot === slotKey;
    },
    [sourceItem]
  );

  // Birak -> giydir. HIZLI equip yolu (ox useItem gecikmesini atlar); sunucu
  // metadata.wear.slot'a takar. Yalniz dogru slota birakilinca.
  const onEquipDrop = useCallback(
    (slotKey: string, source: DragSource) => {
      if (source.inventory !== 'player') return;
      const src = sourceItem(source);
      if (src && (src as any).metadata?.wear?.slot === slotKey) {
        fetchNui('bitirim:equip', { slot: src.slot }).catch(() => {});
      }
    },
    [sourceItem]
  );

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

              return (
                <EquipSlot
                  key={key}
                  slotKey={key}
                  label={label}
                  Icon={Icon}
                  slotNo={slotNo}
                  equipped={equipment[key]}
                  onUnequip={handleUnequip}
                  canEquipHere={canEquipHere}
                  onEquipDrop={onEquipDrop}
                />
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
