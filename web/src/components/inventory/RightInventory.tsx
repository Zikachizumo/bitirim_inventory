import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';

// Bu tiplerde ust baslik (etiket/plaka + KG bari) gizlenir — kullanici istegi:
// araba bagajinda plaka+KG, yerdeki drop'ta "DROP #id + KG" gorunmesin.
const HIDE_HEADER_TYPES = ['trunk', 'glovebox', 'drop'];

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);

  return <InventoryGrid inventory={rightInventory} hideHeader={HIDE_HEADER_TYPES.includes(rightInventory.type)} />;
};

export default RightInventory;
