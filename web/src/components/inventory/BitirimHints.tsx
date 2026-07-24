import React from 'react';

/**
 * Bitirim — karakter panelinin altindaki kullanim talimatlari.
 * Eski "adet / Use / Give / Close" kontrol panelinin yerini alir.
 *
 * Not: eski adet kutusunun kaldirilmasi guvenli — sunucu 'ver/al/at'
 * miktarini math.max(1,...) ile kirpiyor (ver=1, at=tum yigin), yarim
 * bolme SHIFT ile calismaya devam ediyor.
 */
const HINTS: { key: string; text: string }[] = [
  { key: 'Sağ Tık', text: 'Giy / Çıkar' },
  { key: 'Sol Tık', text: 'Kullan / Ayır / At' },
  { key: 'Sürükle', text: 'Taşı' },
  { key: 'Shift + Sürükle', text: 'Yarısını Ayır' },
  { key: 'ESC', text: 'Kapat' },
];

const BitirimHints: React.FC = () => (
  <div className="bx-hints">
    <p className="bx-panel-title">Kullanım</p>
    <div className="bx-hint-list">
      {HINTS.map(({ key, text }) => (
        <div className="bx-hint" key={key}>
          <span className="bx-key">{key}</span>
          <span className="bx-hint-text">{text}</span>
        </div>
      ))}
    </div>
  </div>
);

export default BitirimHints;
