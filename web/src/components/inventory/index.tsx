import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import CharacterStats from './CharacterStats';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, selectRightInventory, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { setPlayerStatus, PlayerStatus } from '../../store/playerStatus';
import {
  setEquippedSlot,
  setEquippedWeapon,
  setEquipment,
  setClothingMap,
  EquipmentMap,
  EquippedWeapon,
  ClothingMap,
} from '../../store/equipment';
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

  // Bitirim: canli studio sahnesi (klon+kamera+backdrop). Karakter panelinde VE
  // kap gorunumlerinde (torpido/bagaj/motel/otel — hasContainer) acik; drop'ta
  // KAPALI. Kapta klon GIZLI kalir (showCharacter:false, sadece backdrop gorunur) —
  // kullanici karakterin SADECE karakter panelinde gorunmesini istiyor, ama arka
  // plani (bitirim_props.ytyp) kap panellerinde de esitlenmesini istedi. Client
  // (character_client.lua) sahneyi yonetir.
  useEffect(() => {
    const sceneOpen = inventoryVisible && !isDrop;
    const showCharacter = !isDrop && !hasContainer;
    fetchNui('bitirim:charScene', { open: sceneOpen, showCharacter }).catch(() => {});
  }, [inventoryVisible, isDrop, hasContainer]);

  // Bitirim: STUDIO KAMERA kadraj kontrolleri (yalniz karakter paneli acikken).
  //   Ok tuslari  = kadraj konumu, 2 EKSEN: yukari/asagi = kamera yuksekligi (dikey
  //                 eksen), sag/sol = kamera yatay ofseti (yatay eksen). Ikisi
  //                 birlikte de kullanilabilir (basili tutunca tekrarlar).
  //   Numpad 1/2  = ZOOM (3. eksen: yakinlastir / uzaklastir).
  // Karakter, oyuncunun konumunun ustunde durur (acilista hesaplanir); bu tuslar
  // sadece stüdyo kamerasinin o karaktere gore kadrajini ayarlar.
  // Karakter sag/sola donme yine fare surukleme ile (char-view uzerinde).
  useEffect(() => {
    const showChar = inventoryVisible && !isDrop && !hasContainer;
    if (!showChar) return;
    const onKey = (e: KeyboardEvent) => {
      let action: string | null = null;
      switch (e.code) {
        case 'ArrowUp': action = 'up'; break;
        case 'ArrowDown': action = 'down'; break;
        case 'ArrowLeft': action = 'left'; break;
        case 'ArrowRight': action = 'right'; break;
        case 'Numpad1': action = 'zoomin'; break;
        case 'Numpad2': action = 'zoomout'; break;
      }
      if (action) {
        e.preventDefault();
        fetchNui('bitirim:charTune', { action }).catch(() => {});
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

  // Bitirim: tooltip artik TIKLA-ac (kalici). Envanter her kapanista (ESC / dis /
  // setInventoryVisible false) acik tooltip'i kapat -> tekrar acinca eski item'in
  // bilgi penceresi asili kalmasin.
  useEffect(() => {
    if (!inventoryVisible) {
      dispatch(closeTooltip());
      dispatch(closeContextMenu());
    }
  }, [inventoryVisible, dispatch]);

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

  // Bitirim: kusanili silah -> karakter panelindeki SILAH slotu gosterimi
  useNuiEvent<EquippedWeapon | false | null>('setEquippedWeapon', (data) => dispatch(setEquippedWeapon(data)));

  // Bitirim: giyili kiyafet/ekipman (slot -> gorunum). Karakter panelini doldurur.
  useNuiEvent<EquipmentMap>('setEquipment', (data) => dispatch(setEquipment(data)));

  // Bitirim: legacy kiyafet item -> slot haritasi (surukle-giy highlight'i icin)
  useNuiEvent<ClothingMap>('setClothingMap', (data) => dispatch(setClothingMap(data)));

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
  // Bitirim: .bx-scrim = pencere DISI tam ekran karartma (%75 opak siyah, HER
  // envanter gorunumunde). Pencere ICINDE ise (drop haric) SOL panel (karakter/
  // torpido/bagaj/motel/depo) + SAG panel (kendi envanterimiz) BIRLIKTE clip-path
  // DELIGIYLE 3D studio backdrop'unu (bitirim_props.ytyp) gosterir -> tum panellerin
  // arka plan opakligi TEK NOKTADAN (preview_manager.lua cfg.balpha) gelir, ayri bir
  // scrim degeri YOK (updateHole, asagida). Kapta klon GIZLI (showCharacter:false)
  // ama backdrop gorunur.
  const scrimRef = useRef<HTMLDivElement>(null);
  const windowBgRef = useRef<HTMLDivElement>(null);
  const scaleRef = useRef(1);
  useLayoutEffect(() => {
    if (!inventoryVisible) return;
    const el = windowRef.current;
    if (!el) return;
    const updateHole = () => {
      // Bitirim: TEK DELIK, SOL+SAG panelleri BIRLIKTE kapsar (union rect) -> arka
      // plan opakligi TEK NOKTADAN (preview_manager.lua cfg.balpha) gelir, sag panel
      // (kendi envanterimiz) artik ayri bir scrim degeriyle degil, SOL panelle (karakter/
      // torpido/bagaj/motel/depo) AYNI 3D backdrop'u gosterir. Kamera DEGISMEZ. Drop
      // acikken hicbiri yok -> delik yok (duz karartma kalir).
      const scrim = scrimRef.current;
      const bg = windowBgRef.current;
      const leftView = (document.querySelector('.bx-char-view') ||
        document.querySelector('.bx-panel.bx-container')) as HTMLElement | null;
      const rightView = document.querySelector('.bx-panel.bx-inventory') as HTMLElement | null;
      const views = [leftView, rightView].filter(Boolean) as HTMLElement[];
      const s = scaleRef.current || 1;
      if (views.length === 0) {
        if (scrim) { scrim.style.clipPath = 'none'; (scrim.style as any).webkitClipPath = 'none'; }
        if (bg) { bg.style.clipPath = 'none'; (bg.style as any).webkitClipPath = 'none'; }
        return;
      }
      const rects = views.map((v) => v.getBoundingClientRect());
      const vLeft = Math.min(...rects.map((r) => r.left));
      const vTop = Math.min(...rects.map((r) => r.top));
      const vRight = Math.max(...rects.map((r) => r.right));
      const vBottom = Math.max(...rects.map((r) => r.bottom));
      if (scrim) {
        const L = Math.max(0, vLeft), T = Math.max(0, vTop), R = vRight, B = vBottom;
        const poly =
          `polygon(evenodd, 0px 0px, 100vw 0px, 100vw 100vh, 0px 100vh, 0px 0px, ` +
          `${L}px ${T}px, ${R}px ${T}px, ${R}px ${B}px, ${L}px ${B}px, ${L}px ${T}px)`;
        scrim.style.clipPath = poly;
        (scrim.style as any).webkitClipPath = poly;
      }
      if (bg) {
        const w = el.getBoundingClientRect();
        const L = (vLeft - w.left) / s, T = (vTop - w.top) / s;
        const R = (vRight - w.left) / s, B = (vBottom - w.top) / s;
        const poly =
          `polygon(evenodd, 0px 0px, 100% 0px, 100% 100%, 0px 100%, 0px 0px, ` +
          `${L}px ${T}px, ${R}px ${T}px, ${R}px ${B}px, ${L}px ${B}px, ${L}px ${T}px)`;
        bg.style.clipPath = poly;
        (bg.style as any).webkitClipPath = poly;
      }
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
