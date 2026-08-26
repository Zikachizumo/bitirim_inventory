import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';
import ClothingShop from './components/inventory/ClothingShop';

debugData([
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'test',
        type: 'player',
        slots: 50,
        label: 'Bob Smith',
        weight: 3000,
        maxWeight: 5000,
        items: [
          {
            slot: 1,
            name: 'iron',
            weight: 3000,
            metadata: {
              description: `name: Svetozar Miletic  \n Gender: Male`,
              ammo: 3,
              mustard: '60%',
              ketchup: '30%',
              mayo: '10%',
            },
            count: 5,
          },
          { slot: 2, name: 'powersaw', weight: 0, count: 1, metadata: { durability: 75 } },
          { slot: 3, name: 'copper', weight: 100, count: 12, metadata: { type: 'Special' } },
          {
            slot: 4,
            name: 'water',
            weight: 100,
            count: 1,
            metadata: { description: 'Generic item description' },
          },
          { slot: 5, name: 'water', weight: 100, count: 1 },
          {
            slot: 6,
            name: 'backwoods',
            weight: 100,
            count: 1,
            metadata: {
              label: 'Russian Cream',
              imageurl: 'https://i.imgur.com/2xHhTTz.png',
            },
          },
        ],
      },
      rightInventory: {
        id: 'shop',
        type: 'crafting',
        slots: 5000,
        label: 'Bob Smith',
        weight: 3000,
        maxWeight: 5000,
        items: [
          {
            slot: 1,
            name: 'lockpick',
            weight: 500,
            price: 300,
            ingredients: {
              iron: 5,
              copper: 12,
              powersaw: 0.1,
            },
            metadata: {
              description: 'Simple lockpick that breaks easily and can pick basic door locks',
            },
          },
        ],
      },
    },
  },
]);

// Bitirim: kiyafet magazasi tarayici-gelistirme onizlemesi (SADECE DEV+browser'da
// tetiklenir, ayni debugData deseni). /magaza komutu ile Lua'dan gelen gercek
// setShopVisible olayini taklit eder.
debugData([
  {
    action: 'setShopVisible',
    data: {
      visible: true,
      catalog: {
        categories: [
          { id: 'headwear', label: 'Headwear', icon: 'IconCap' },
          { id: 'outerwear', label: 'Outerwear', icon: 'IconJacket' },
          { id: 'tshirts', label: 'T-Shirts', icon: 'IconTshirt' },
          { id: 'pants', label: 'Pants', icon: 'IconPants' },
          { id: 'shoes', label: 'Shoes', icon: 'IconShoes' },
          { id: 'glasses', label: 'Glasses', icon: 'IconGlasses' },
        ],
        items: [
          { id: 'hw_beanie_01', category: 'headwear', label: 'Muška kapa', price: 900, slot: 'hat' },
          { id: 'hw_cap_01', category: 'headwear', label: 'Muška kapa (Šapka)', price: 750, slot: 'hat' },
          { id: 'ow_bomber_01', category: 'outerwear', label: 'Muška vanjska odeća', price: 2025, slot: 'jacket' },
          { id: 'ts_basic_01', category: 'tshirts', label: 'Muška majica', price: 1500, slot: 'tshirt' },
          { id: 'pt_jeans_01', category: 'pants', label: 'Muške pantalone', price: 900, slot: 'pants' },
          { id: 'sh_sneaker_01', category: 'shoes', label: 'Muške cipele', price: 1275, slot: 'shoes' },
          { id: 'gl_dark_01', category: 'glasses', label: 'Muške naočare', price: 1500, slot: 'glasses' },
        ],
      },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
  }>('init', ({ locale, items, leftInventory, imagepath }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    dispatch(setupInventory({ leftInventory }));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <ClothingShop />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
