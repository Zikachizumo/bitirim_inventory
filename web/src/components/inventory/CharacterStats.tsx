import React from 'react';
import { useAppSelector } from '../../store';
import { selectPlayerStatus } from '../../store/playerStatus';
import { IconDrop, IconFood, IconHeart, IconShield } from './BitirimIcons';

/**
 * Bitirim — CAN / ZIRH / AÇLIK / SUSUZLUK stat blogu.
 * Hem karakter panelinde hem drop panelinde (altta) kullanilir.
 * Yalnizca client Lua gercek veri gonderdiginde gorunur.
 */

const Stat: React.FC<{ kind: string; label: string; value: number; Icon: React.FC<{ size?: number }> }> = ({
  kind,
  label,
  value,
  Icon,
}) => (
  <div className={`bx-stat bx-stat-${kind}`}>
    <div className="bx-stat-top">
      <Icon size={18} />
      <span className="bx-stat-label">{label}</span>
      <span className="bx-stat-pct">{Math.round(value)}%</span>
    </div>
    <div className="bx-bar">
      <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </div>
  </div>
);

const CharacterStats: React.FC = () => {
  const status = useAppSelector(selectPlayerStatus);
  if (!status) return null;

  return (
    <div className="bx-stats">
      <Stat kind="can" label="Can" value={status.health} Icon={IconHeart} />
      <Stat kind="zirh" label="Zırh" value={status.armour} Icon={IconShield} />
      {status.hunger !== undefined && <Stat kind="aclik" label="Açlık" value={status.hunger} Icon={IconFood} />}
      {status.thirst !== undefined && <Stat kind="susuzluk" label="Susuzluk" value={status.thirst} Icon={IconDrop} />}
    </div>
  );
};

export default CharacterStats;
