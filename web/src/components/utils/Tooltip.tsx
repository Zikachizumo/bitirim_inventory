import { flip, FloatingPortal, offset, shift, useFloating, useTransitionStyles } from '@floating-ui/react';
import React, { useEffect } from 'react';
import { useAppSelector } from '../../store';
import SlotTooltip from '../inventory/SlotTooltip';

const Tooltip: React.FC = () => {
  const hoverData = useAppSelector((state) => state.tooltip);

  const { refs, context, floatingStyles } = useFloating({
    middleware: [flip(), shift({ padding: 8 }), offset({ mainAxis: 10 })],
    open: hoverData.open,
    placement: 'right-start',
  });

  const { isMounted, styles } = useTransitionStyles(context, {
    duration: 200,
  });

  // Tooltip artik tiklanan SLOTA sabitlenir (mouse takibi yok). coords = slot rect'i;
  // placement 'right-start' -> slotun sagina, yer yoksa flip ile soluna acilir.
  useEffect(() => {
    const c = hoverData.coords;
    if (!c) return;
    refs.setPositionReference({
      getBoundingClientRect() {
        return {
          width: c.width,
          height: c.height,
          x: c.x,
          y: c.y,
          left: c.x,
          top: c.y,
          right: c.x + c.width,
          bottom: c.y + c.height,
        };
      },
    });
  }, [hoverData.coords, refs]);

  return (
    <>
      {isMounted && hoverData.item && hoverData.inventoryType && (
        <FloatingPortal>
          <SlotTooltip
            ref={refs.setFloating}
            style={{ ...floatingStyles, ...styles }}
            item={hoverData.item!}
            inventoryType={hoverData.inventoryType!}
          />
        </FloatingPortal>
      )}
    </>
  );
};

export default Tooltip;
