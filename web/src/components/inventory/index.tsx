import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import CharacterStats from './CharacterStats';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, selectRightInventory, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { setPlayerStatus, PlayerStatus } from '../../store/playerStatus';
import { setEquippedSlot, setEquipment, EquipmentMap } from '../../store/equipment';
import { setBagLevel } from '../../store/backpack';
import { setCash } from '../../store/cash';
import { useExitListener } from '../../hooks/useExitListener';
import { fetchNui } from '../../utils/fetchNui';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import { closeSplit } from '../../store/split';
import Fade from '../utils/transitions/Fade';
import BitirimTopBar from './BitirimTopBar';
import CharacterPanel from './CharacterPanel';
import PlayerPanel from './PlayerPanel';
import GiveBar from './GiveBar';
import DropPanel from './DropPanel';
import SplitDialog from './SplitDialog';

/**
 * Bitirim envanter penceresi.
 *
 * Yerlesim (onaylanmis mockup):
 *   ust bar
 *   sol sutun : Karakter paneli — bir kap acikken yerini o kap alir (A secenegi)
 *   sag sutun : oyuncunun envanteri (grid + dikey makro sutunu + canta karti)
 *   alt satir : kullanim talimatlari + "Surukle & Ver" bari
 *
 * Eski InventoryControl (adet/Use/Give/Close) kaldirildi; yerine kullanim
 * talimatlari (BitirimHints) kondu. Kaldirmak guvenli: sunucu ver/al/at
 * miktarini math.max(1,...) ile kirpiyor, yarim bolme SHIFT ile calisiyor.
 */
const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch = useAppDispatch();
  const rightInventory = useAppSelector(selectRightInventory);

  // Sag envanterin durumu. Bos id = hicbir sey acik degil.
  // 'drop' (yerdeki item) ayri ele alinir: 5x5 grid + altta karakter statlari.
  // Diger kaplar (stash/bagaj/torpido/market) karakter panelinin yerini alir.
  const isDrop = !!rightInventory.id && rightInventory.type === 'drop';
  const hasContainer = !!rightInventory.id && rightInventory.type !== 'drop';

  // Envanter kapaninca (ESC dahil, tum yollar) Divide diyalogu da kapansin.
  useEffect(() => {
    if (!inventoryVisible) dispatch(closeSplit());
  }, [inventoryVisible, dispatch]);

  // Bitirim: canli karakter sahnesi — yalniz KARAKTER paneli goruntulenirken acik
  // (kap/drop acikken karakter paneli gizli, o yuzden sahne de kapali). Client
  // (character_client.lua) klon+kamera+isik sahnesini yonetir.
  useEffect(() => {
    const showChar = inventoryVisible && !isDrop && !hasContainer;
    fetchNui('bitirim:charScene', { open: showChar }).catch(() => {});
  }, [inventoryVisible, isDrop, hasContainer]);

  // Bitirim: 8 KEY ISIK klavye ayari (karakter sahnesi acikken). 1-8 = isik SEC;
  // ok tuslari = konum, Numpad 5/2 = zoom (derinlik), Numpad 8/7 = parlaklik ac/kis.
  // client Lua secili isigi klon uzerinde ayarlar; GAMEPLAY KAMERASI DEGISMEZ.
  useEffect(() => {
    const showChar = inventoryVisible && !isDrop && !hasContainer;
    if (!showChar) return;
    const onKey = (e: KeyboardEvent) => {
      let action: string | null = null;
      switch (e.code) {
        case 'ArrowLeft': action = 'left'; break;
        case 'ArrowRight': action = 'right'; break;
        case 'ArrowUp': action = 'up'; break;
        case 'ArrowDown': action = 'down'; break;
        case 'Numpad8': action = 'bright'; break;
        case 'Numpad7': action = 'dim'; break;
        case 'Numpad5': action = 'zoomin'; break;
        case 'Numpad2': action = 'zoomout'; break;
        case 'Digit1': action = '1'; break;
        case 'Digit2': action = '2'; break;
        case 'Digit3': action = '3'; break;
        case 'Digit4': action = '4'; break;
        case 'Digit5': action = '5'; break;
        case 'Digit6': action = '6'; break;
        case 'Digit7': action = '7'; break;
        case 'Digit8': action = '8'; break;
      }
      if (action) {
        e.preventDefault();
        fetchNui('bitirim:lightTune', { action }).catch(() => {});
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [inventoryVisible, isDrop, hasContainer]);

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  // Bitirim: karakter panelindeki durum barlari (client Lua'dan gercek veri)
  useNuiEvent<PlayerStatus>('setPlayerStatus', (data) => dispatch(setPlayerStatus(data)));

  // Bitirim: o an kusanili slot (sag tik menusunde Use/Unequip etiketi icin)
  useNuiEvent<number | null>('setEquippedSlot', (data) => dispatch(setEquippedSlot(data)));

  // Bitirim: giyili kiyafet/ekipman (slot -> gorunum). Karakter panelini doldurur.
  useNuiEvent<EquipmentMap>('setEquipment', (data) => dispatch(setEquipment(data)));

  // Bitirim: canta seviyesi -> tema rengi (<html data-lv>) + acik/kilitli slotlar
  useNuiEvent<number>('setBagLevel', (level) => {
    dispatch(setBagLevel(level));
    document.documentElement.dataset.lv = String(Math.max(0, Math.min(5, Math.floor(level || 0))));
  });

  // Bitirim: nakit (qbx cash) -> ust bar. Nakit artik envanter item'i degil.
  useNuiEvent<number>('setCash', (amount) => dispatch(setCash(amount)));

  // Bitirim: OTOMATIK OLCEKLEME — pencereyi ekrana sigacak/dolduracak sekilde
  // olcekle (tam ekran his). Dogal boyutu olcup min(vw,vh) orani ile scale eder.
  const windowRef = useRef<HTMLDivElement>(null);
  // Bitirim: arka plan SAYDAM (oyun gorunur). Kenar (pencere disi) oyun BLURLANIR
  // (.bx-scrim). Pencere %75 opak koyu cam (.bx-window-bg). Karakter onizlemesi
  // (.bx-char-view) HEM scrim'de (blur atlanir) HEM %75 tint katmaninda (tint
  // atlanir) clip-path DELIK -> ped'in arkasinda TAM PARLAKLIK oyun/harita gorunur,
  // ped NET. Kap/drop acikken char yok -> delik yok.
  const scrimRef = useRef<HTMLDivElement>(null);
  const windowBgRef = useRef<HTMLDivElement>(null);
  const scaleRef = useRef(1);
  useLayoutEffect(() => {
    if (!inventoryVisible) return;
    const el = windowRef.current;
    if (!el) return;
    const updateHole = () => {
      // Bitirim (kullanici istegi): char-view'de clip-path DELIK ACILMAZ -> scrim +
      // window-bg katmanlari char-view'i de aynen kaplar. Boylece karakter bolgesi
      // envanterin geri kalaniyla EŞIT (tek parca), ayri delik/kare yok.
      const scrim = scrimRef.current;
      const bg = windowBgRef.current;
      if (scrim) { scrim.style.clipPath = 'none'; (scrim.style as any).webkitClipPath = 'none'; }
      if (bg) { bg.style.clipPath = 'none'; (bg.style as any).webkitClipPath = 'none'; }
    };
    const fit = () => {
      const w = el.offsetWidth;
      const h = el.offsetHeight;
      if (!w || !h) return;
      // 1 tavan: 90px slot boyutunu buyutme, yalniz ekrana sigmiyorsa kucult.
      const s = Math.min(1, (window.innerWidth * 0.99) / w, (window.innerHeight * 0.985) / h);
      el.style.transform = `scale(${s})`;
      scaleRef.current = s;
      updateHole(); // transform sonrasi gercek dikdortgeni oku
    };
    fit();
    const t = window.setTimeout(fit, 60); // layout otursun
    const t2 = window.setTimeout(updateHole, 180); // ekipman/gorsel oturunca yeniden
    window.addEventListener('resize', fit);
    return () => {
      window.clearTimeout(t);
      window.clearTimeout(t2);
      window.removeEventListener('resize', fit);
    };
  }, [inventoryVisible, isDrop, hasContainer]);

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          {/* Kenar (pencere disi) oyun BLUR — karartma yok. char-view deligi acilir. */}
          <div className="bx-scrim" ref={scrimRef} />
          <div className="bx-window" ref={windowRef}>
            {/* Pencere SIYAH arka katman (opak); char-view bolumu clip-path DELIK. */}
            <div className="bx-window-bg" ref={windowBgRef} />
            <BitirimTopBar />

            {/* 2x2 grid: satir1 = ana kutular (esit yukseklik),
                satir2 = alt barlar (esit yukseklik). align-items:stretch her
                hucreyi satir yuksekligine ceker. */}
            <div className="bx-body">
              {isDrop ? (
                <DropPanel />
              ) : hasContainer ? (
                <div className="bx-panel bx-container">
                  <RightInventory />
                </div>
              ) : (
                <CharacterPanel />
              )}
              <PlayerPanel />
              {/* Bitirim: Kullanim talimatlari kaldirildi. Alt-sol hucre = statlar
                  (Surukle&Ver ile ayni satir -> ayni yukseklik). Drop modunda
                  DropPanel kendi statini gosterir, burasi bos. */}
              {isDrop ? (
                <div />
              ) : (
                <div className="bx-statsbar">
                  <CharacterStats />
                </div>
              )}
              <GiveBar />
            </div>
          </div>

          <Tooltip />
          <InventoryContext />
          <SplitDialog />
        </div>
      </Fade>
      <InventoryHotbar />
    </>
  );
};

export default Inventory;
