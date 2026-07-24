import React, { useMemo } from 'react';
import InventoryGrid from './InventoryGrid';
import InventorySlot from './InventorySlot';
import WeightBar from '../utils/WeightBar';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import { IconBackpack, IconWeight } from './BitirimIcons';

const HOTBAR_SLOTS = 5;
const GRID_SLOTS = 40; // 8 sutun x 5 satir

/**
 * Bitirim sag panel — oyuncunun kendi envanteri.
 *
 * Yerlesim:
 *   baslik (etiket + agirlik bari)      ← tam genislik
 *   [ 8x5 grid ] [ dikey 1-5 makro ]    ← makro N, grid SATIR N ile hizali
 *   canta karti
 *
 * Grid 40 slotla sinirli; makro slotlari (1-5) gridde tekrar etmesin diye
 * skipSlots=5 verilir, boylece toplam gorunen 45 slot (5 makro + 40 grid).
 */
const PlayerPanel: React.FC = () => {
  const inventory = useAppSelector(selectLeftInventory);

  const hotbarItems = useMemo(() => inventory.items.slice(0, HOTBAR_SLOTS), [inventory.items]);
  const usedSlots = useMemo(() => inventory.items.filter((item) => !!item?.name).length, [inventory.items]);
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );

  return (
    <div className="bx-panel bx-inventory">
      <div className="bx-inv-head">
        <p className="bx-panel-title">Envanter</p>
        {inventory.maxWeight ? (
          <div className="bx-weight">
            <span className="bx-weight-lab">
              <IconWeight size={16} />
              {weight / 1000} / {inventory.maxWeight / 1000} KG
            </span>
            <WeightBar percent={(weight / inventory.maxWeight) * 100} />
          </div>
        ) : null}
      </div>

      <div className="bx-inv-main">
        <InventoryGrid inventory={inventory} skipSlots={HOTBAR_SLOTS} maxSlots={GRID_SLOTS} hideHeader />

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
