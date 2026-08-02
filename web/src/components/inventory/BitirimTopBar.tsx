import React from 'react';
import { useAppSelector } from '../../store';
import { selectCash } from '../../store/cash';
import { fetchNui } from '../../utils/fetchNui';
import { IconBrandBag, IconCash, IconClose } from './BitirimIcons';

/**
 * Bitirim ust bari — marka, tasinan nakit, kapat.
 *
 * Nakit qbx_core/account sisteminden gelir (GrandRP mantigi: nakit envanter
 * item'i DEGIL). Client Lua `setCash` ile yollar. 0 ise rozet gosterilmez.
 */
const BitirimTopBar: React.FC = () => {
  const cash = useAppSelector(selectCash);

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
