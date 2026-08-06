import React, { useMemo } from 'react';
import InventoryGrid from './InventoryGrid';
import InventorySlot from './InventorySlot';
import WeightBar from '../utils/WeightBar';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { selectBagLevel, unlockedGridSlots, BAG_CAP_KG } from '../../store/backpack';
import { getTotalWeight } from '../../helpers';
import { IconBackpack, IconWeight } from './BitirimIcons';

const HOTBAR_SLOTS = 7; // Fast Access (makro) slotlari
const GRID_SLOTS = 40; // 7 sutun x ~6 satir (Backpack)

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
  const bagLevel = useAppSelector(selectBagLevel);
  const unlocked = unlockedGridSlots(bagLevel); // acik grid slotu (kilitli olanlar bundan sonra)
  const capKg = BAG_CAP_KG[bagLevel]; // seviye KG kapasitesi (agirlik bari + kart)

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
        {/* Agirlik bari, kullanilan canta seviyesinin KG kapasitesine gore.
            (Sunucu tarafi SetMaxWeight backend'de baglaninca gercek sinir da bu olur.) */}
        <div className="bx-weight">
          <span className="bx-weight-lab">
            <IconWeight size={16} />
            {(weight / 1000).toLocaleString('en-us', { minimumFractionDigits: 2 })} / {capKg} KG
          </span>
          <WeightBar percent={Math.min(100, (weight / (capKg * 1000)) * 100)} />
        </div>
      </div>

      {/* Fast Access (makro 1-7): grid'in USTUNDE yatay sira. */}
      <p className="bx-sec-title">Fast Access</p>
      <div className="bx-hotrow" title="Hizli erisim slotlari (1-7)">
        {hotbarItems.map((item) => (
          <InventorySlot
            key={`hotrow-${inventory.id}-${item.slot}`}
            item={item}
            inventoryId={inventory.id}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
          />
        ))}
      </div>

      <p className="bx-sec-title">Backpack</p>
      <InventoryGrid
        inventory={inventory}
        skipSlots={HOTBAR_SLOTS}
        maxSlots={GRID_SLOTS}
        hideHeader
        lockedFrom={unlocked}
      />

      {/* Alt bolge: canta karti panelin ALTINA itilir (margin-top:auto). */}
      <div className="bx-inv-bottom">
      {/* Canta karti — gercek slot/agirlik verisi.
          Seviye rozeti, canta seviye sistemi baglanana kadar gosterilmiyor. */}
      <div className="bx-bpcard">
        <div className="bx-bp-avatar">
          <IconBackpack size={28} />
        </div>
        <div className="bx-bp-main">
          <div className="bx-bp-title">
            <b>Backpack</b>
            <span className="bx-bp-lv">{bagLevel > 0 ? `Level ${bagLevel}` : 'No Backpack'}</span>
          </div>
          <p className="bx-bp-desc">
            Carry more as you level up — locked slots unlock each level. Keep carrying to reach the next tier.
          </p>
        </div>
        <div className="bx-bp-stats">
          <div className="bx-bp-stat">
            <span className="bx-bp-n">
              {usedSlots}
              <span className="bx-bp-u"> / {HOTBAR_SLOTS + unlocked}</span>
            </span>
            <span className="bx-bp-k">Used</span>
          </div>
          <div className="bx-bp-stat">
            <span className="bx-bp-n">
              {BAG_CAP_KG[bagLevel]}
              <span className="bx-bp-u"> KG</span>
            </span>
            <span className="bx-bp-k">Capacity</span>
          </div>
        </div>
      </div>
      </div>
    </div>
  );
};

export default PlayerPanel;
