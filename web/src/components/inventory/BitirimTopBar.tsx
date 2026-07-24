import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { fetchNui } from '../../utils/fetchNui';
import { IconBrandBag, IconCash, IconClose } from './BitirimIcons';

/**
 * Bitirim ust bari — marka, tasinan nakit, kapat.
 *
 * Nakit oyuncunun envanterindeki 'money' item'indan hesaplanir (gercek veri).
 * Item yoksa rozet hic gosterilmez — uydurma bakiye yazilmaz.
 */
const BitirimTopBar: React.FC = () => {
  const leftInventory = useAppSelector(selectLeftInventory);

  const cash = useMemo(
    () =>
      leftInventory.items.reduce((total, item) => (item?.name === 'money' ? total + (item.count ?? 0) : total), 0),
    [leftInventory.items]
  );

  return (
    <div className="bx-topbar">
      <div className="bx-brandmark">
        <IconBrandBag size={23} />
      </div>
      <div className="bx-brand">Bitirim Uclu RP</div>

      <div className="bx-topbar-right">
        {cash > 0 && (
          <div className="bx-pill bx-pill-money">
            <IconCash size={16} />
            <span className="bx-pill-value">${cash.toLocaleString('tr-TR')}</span>
          </div>
        )}
        <button className="bx-close" onClick={() => fetchNui('exit')} title="Kapat (ESC)">
          <IconClose size={18} />
        </button>
      </div>
    </div>
  );
};

export default BitirimTopBar;
