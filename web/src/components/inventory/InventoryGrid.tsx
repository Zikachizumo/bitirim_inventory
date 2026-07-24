import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import { IconLock } from './BitirimIcons';

const PAGE_SIZE = 30;

/**
 * Bitirim eklentileri:
 *  - skipSlots : bastaki N slotu atla (oyuncu envanterinde 1-5 makro sutununda
 *    gosterildigi icin gridde tekrar edilmezler).
 *  - maxSlots  : gridde gosterilecek AZAMI slot sayisi. Oyuncu gridi 8x5=40 ile
 *    sinirli olmali; fazlasi ('5 fazladan kutu') gosterilmez.
 *  - hideHeader: baslik + agirlik barini gizler. Oyuncu panelinde bunlar tam
 *    genislikte ust satirda ayri gosterilir ki makro sutunu grid SATIRLARIYLA
 *    hizalansin (makro 1 <-> satir 1).
 */
const InventoryGrid: React.FC<{
  inventory: Inventory;
  skipSlots?: number;
  maxSlots?: number;
  hideHeader?: boolean;
  /** Bu pozisyondan itibaren (0-based, gridde) slotlar KILITLI gosterilir
   *  (canta seviyesi). undefined = hicbiri kilitli degil. */
  lockedFrom?: number;
}> = ({ inventory, skipSlots = 0, maxSlots, hideHeader = false, lockedFrom }) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  // maxSlots verildiginde (oyuncu gridi = 40) hepsini tek seferde goster;
  // sayfalama sadece buyuk kaplar (stash vb.) icin gereklidir.
  const paginated = maxSlots === undefined;
  const end = paginated ? skipSlots + (page + 1) * PAGE_SIZE : skipSlots + maxSlots;

  return (
    <>
      <div className="inventory-grid-wrapper" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
        {!hideHeader && (
          <div>
            <div className="inventory-grid-header-wrapper">
              <p>{inventory.label}</p>
              {inventory.maxWeight && (
                <p>
                  {weight / 1000}/{inventory.maxWeight / 1000}kg
                </p>
              )}
            </div>
            <WeightBar percent={inventory.maxWeight ? (weight / inventory.maxWeight) * 100 : 0} />
          </div>
        )}
        <div className="inventory-grid-container" ref={containerRef}>
          <>
            {inventory.items.slice(skipSlots, end).map((item, index) =>
              lockedFrom !== undefined && index >= lockedFrom ? (
                // Canta seviyesiyle kilitli slot — asma kilit, etkilesimsiz.
                <div className="inventory-slot bx-slot-locked" key={`locked-${inventory.id}-${item.slot}`}>
                  <IconLock size={22} />
                </div>
              ) : (
                <InventorySlot
                  key={`${inventory.type}-${inventory.id}-${item.slot}`}
                  item={item}
                  ref={paginated && index === end - skipSlots - 1 ? ref : null}
                  inventoryType={inventory.type}
                  inventoryGroups={inventory.groups}
                  inventoryId={inventory.id}
                />
              )
            )}
          </>
        </div>
      </div>
    </>
  );
};

export default InventoryGrid;
