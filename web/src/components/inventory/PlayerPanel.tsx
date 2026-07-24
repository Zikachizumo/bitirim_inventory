import React, { useMemo } from 'react';
import InventoryGrid from './InventoryGrid';
import InventorySlot from './InventorySlot';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { IconBackpack } from './BitirimIcons';

const HOTBAR_SLOTS = 5;

/**
 * Bitirim sag panel — oyuncunun kendi envanteri.
 *
 * Yerlesim: grid (1-5 haric) + sagda dikey makro sutunu + altta canta karti.
 * Makro slotlari gridde tekrar etmesin diye InventoryGrid'e skipSlots verilir.
 */
const PlayerPanel: React.FC = () => {
  const inventory = useAppSelector(selectLeftInventory);

  const hotbarItems = useMemo(() => inventory.items.slice(0, HOTBAR_SLOTS), [inventory.items]);

  const usedSlots = useMemo(() => inventory.items.filter((item) => !!item?.name).length, [inventory.items]);

  return (
    <div className="bx-panel bx-inventory">
      <p className="bx-panel-title">Envanter</p>

      <div className="bx-inv-main">
        <InventoryGrid inventory={inventory} skipSlots={HOTBAR_SLOTS} />

        <div className="bx-hotcol" title="Makro slotları (1-5)">
          {hotbarItems.map((item) => (
            <InventorySlot
              key={`hotcol-${inventory.id}-${item.slot}`}
              item={item}
              inventoryId={inventory.id}
              inventoryType={inventory.type}
              inventoryGroups={inventory.groups}
            />
          ))}
        </div>
      </div>

      {/* Canta karti — gercek slot/agirlik verisi.
          Seviye rozeti, canta seviye sistemi baglanana kadar gosterilmiyor. */}
      <div className="bx-bpcard">
        <div className="bx-bp-avatar">
          <IconBackpack size={28} />
        </div>
        <div className="bx-bp-main">
          <div className="bx-bp-title">
            <b>Backpack</b>
          </div>
          <p className="bx-bp-desc">
            Carry more as you level up — locked slots unlock each level. Keep carrying to reach the next tier.
          </p>
        </div>
        <div className="bx-bp-stats">
          <div className="bx-bp-stat">
            <span className="bx-bp-n">
              {usedSlots}
              <span className="bx-bp-u"> / {inventory.slots}</span>
            </span>
            <span className="bx-bp-k">Used</span>
          </div>
          <div className="bx-bp-stat">
            <span className="bx-bp-n">
              {Math.floor((inventory.maxWeight ?? 0) / 1000)}
              <span className="bx-bp-u"> KG</span>
            </span>
            <span className="bx-bp-k">Capacity</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PlayerPanel;
