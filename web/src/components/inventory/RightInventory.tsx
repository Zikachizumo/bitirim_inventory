import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';

// Bu tiplerde ust baslik (etiket/plaka + KG bari) gizlenir:
//  - trunk (bagaj): agirlik siniri pratikte yok, plaka+KG istenmiyor
//  - drop (yerdeki): "DROP #id + KG" istenmiyor (DropPanel kendi temiz basligini koyar)
// Torpido (glovebox) HARIC: 50 KG siniri oldugu icin agirlik bari GORUNUR kalir.
const HIDE_HEADER_TYPES = ['trunk', 'drop'];

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);

  return <InventoryGrid inventory={rightInventory} hideHeader={HIDE_HEADER_TYPES.includes(rightInventory.type)} />;
};

export default RightInventory;
