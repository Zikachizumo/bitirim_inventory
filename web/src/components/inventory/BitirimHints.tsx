import React from 'react';

/**
 * Bitirim — karakter panelinin altindaki kullanim talimatlari (2x2 duzen).
 * Eski "adet / Use / Give / Close" kontrol panelinin yerini alir.
 *
 * Not: yarim bolme SHIFT+surukle ile hala calisir; talimat listesinden
 * kullanicinin istegiyle cikarildi.
 */
const HINTS: { key: string; text: string }[] = [
  { key: 'Sağ Tık', text: 'Giy / Çıkar' },
  { key: 'Sol Tık', text: 'Kullan / Ayır / At' },
  { key: 'Sürükle', text: 'Taşı' },
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
