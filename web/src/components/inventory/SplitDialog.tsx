import React, { useEffect, useState } from 'react';
import { store, useAppDispatch, useAppSelector } from '../../store';
import { selectSplitItem, closeSplit } from '../../store/split';
import { setItemAmount } from '../../store/inventory';
import { onDrop } from '../../dnd/onDrop';
import { Items } from '../../store/items';
import { unlockedGridSlots } from '../../store/backpack';

const HOTBAR_SLOTS = 5;
const PCTS = [0.25, 0.5, 0.75];

/** Yigini `count` adet olacak sekilde bosta ki bir slota bol (ayni envanter). */
const doDivide = (name: string, slot: number, count: number): boolean => {
  const state = store.getState();
  const inv = state.inventory.leftInventory;
  const usable = HOTBAR_SLOTS + unlockedGridSlots(state.backpack.level); // kilitli slota bolme

  const isEmpty = (s: any) => !!s && !s.name && s.slot !== slot && s.slot <= usable;
  // Once GRID'de (slot > 5) bos slot; yoksa makro (1-5) dahil herhangi bir bos slot.
  const empty = inv.items.find((s) => isEmpty(s) && s.slot > HOTBAR_SLOTS) || inv.items.find(isEmpty);
  if (!empty) return false; // bos (acik) slot yok

  store.dispatch(setItemAmount(count));
  onDrop({ inventory: 'player', item: { name, slot } }, { inventory: 'player', item: { slot: empty.slot } });
  store.dispatch(setItemAmount(0));
  return true;
};

const SplitDialog: React.FC = () => {
  const item = useAppSelector(selectSplitItem);
  const dispatch = useAppDispatch();
  const [amount, setAmount] = useState(1);

  // Diyalog acildiginda adet DIREKT 1 gelir.
  useEffect(() => {
    if (item) setAmount(1);
  }, [item]);

  if (!item) return null;

  const max = Math.max(1, item.count - 1); // tum yigin bolunemez, en az 1 kalir
  const label = item.metadata?.label || Items[item.name]?.label || item.name;

  const clamp = (n: number) => Math.max(1, Math.min(max, Math.floor(n) || 1));
  const close = () => dispatch(closeSplit());

  const confirm = () => {
    doDivide(item.name, item.slot, clamp(amount));
    close();
  };

  return (
    <div className="bx-split-overlay" onMouseDown={close}>
      <div className="bx-split" onMouseDown={(e) => e.stopPropagation()}>
        <div className="bx-split-head">
          <b>{label}</b>
          <span>{item.count} adet</span>
        </div>

        <input
          className="bx-split-input"
          type="number"
          min={1}
          max={max}
          value={amount}
          autoFocus
          onChange={(e) => setAmount(clamp(Number(e.target.value)))}
          onKeyDown={(e) => e.key === 'Enter' && confirm()}
        />

        <div className="bx-split-pcts">
          {PCTS.map((p) => (
            <button key={p} className="bx-split-pct" onClick={() => setAmount(clamp(item.count * p))}>
              %{Math.round(p * 100)}
            </button>
          ))}
        </div>

        <button className="bx-split-confirm" onClick={confirm}>
          Böl ({clamp(amount)})
        </button>
      </div>
    </div>
  );
};

export default SplitDialog;
