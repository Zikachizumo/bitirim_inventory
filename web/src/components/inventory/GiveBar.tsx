import React from 'react';
import { useDrop } from 'react-dnd';
import { DragSource } from '../../typings';
import { onGive } from '../../dnd/onGive';
import { IconSend } from './BitirimIcons';

/**
 * Bitirim "Sürükle & Ver" bari.
 *
 * Gercek bir birakma hedefi: envanterden buraya surukledigin item
 * ox'un mevcut `onGive` akisina gider (yanindaki oyuncuya verilir).
 *
 * NOT: mockup'taki "yakindaki oyuncu ID + isim / Stranger" secicisi
 * bitirim_stranger entegrasyonuyla birlikte gelecek. O gelene kadar
 * burada sahte oyuncu kartlari GOSTERILMEZ.
 */
const GiveBar: React.FC = () => {
  const [{ isOver, canDrop }, give] = useDrop<DragSource, void, { isOver: boolean; canDrop: boolean }>(() => ({
    accept: 'SLOT',
    collect: (monitor) => ({
      isOver: monitor.isOver(),
      canDrop: monitor.canDrop(),
    }),
    drop: (source) => {
      if (source.inventory === 'player') onGive(source.item);
    },
  }));

  return (
    <div
      className={`bx-givebar${isOver && canDrop ? ' is-over' : ''}`}
      ref={(el) => {
        give(el);
      }}
    >
      <div className="bx-give-drop">
        <div className="bx-give-icon">
          <IconSend size={22} />
        </div>
        <div className="bx-give-text">
          <b>Sürükle &amp; Ver</b>
          <span>Eşyayı buraya bırak → yanındaki oyuncuya gönder</span>
        </div>
      </div>
    </div>
  );
};

export default GiveBar;
