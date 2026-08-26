import React, { useEffect, useRef } from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import useNuiEvent from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import {
  ShopItem,
  addToCart,
  backToCategories,
  clearCart,
  openCategory,
  selectItem,
  selectShopCart,
  selectShopCartOpen,
  selectShopCategories,
  selectShopItems,
  selectShopQuantity,
  selectShopSelectedCategory,
  selectShopSelectedItem,
  selectShopView,
  selectShopVisible,
  setQuantity,
  setShopVisible,
  toggleCart,
} from '../../store/clothingShop';
import {
  IconBack,
  IconCap,
  IconCart,
  IconGlasses,
  IconJacket,
  IconPants,
  IconShoes,
  IconTshirt,
} from './BitirimIcons';
import ClothingShopCart from './ClothingShopCart';

// Kategori id -> ikon. Katalogdaki `icon` alani (Lua) sadece bir isim tasir;
// gercek bileseni burada karar veririz (mevcut BitirimIcons setiyle AYNI, yeni
// kategori ikonu ICAT ETMEDEN).
const CATEGORY_ICONS: Record<string, React.FC<{ size?: number }>> = {
  headwear: IconCap,
  outerwear: IconJacket,
  tshirts: IconTshirt,
  pants: IconPants,
  shoes: IconShoes,
  glasses: IconGlasses,
};

/**
 * Bitirim — GrandRP tarzı kıyafet mağazası. Kategori listesi → ürün grid'i →
 * seçili üründe canlı karakter önizleme + adet seçici + sepet.
 *
 * Karakter önizlemesi (bx-char-view + sürükle-döndür) CharacterPanel.tsx ile
 * BİREBİR aynı desen — previewPed/kamera zaten çalışan preview_manager.lua'yı
 * kullanır, burada hiçbir kamera kodu tekrarlanmaz.
 */
const ClothingShop: React.FC = () => {
  const dispatch = useAppDispatch();
  const visible = useAppSelector(selectShopVisible);
  const categories = useAppSelector(selectShopCategories);
  const items = useAppSelector(selectShopItems);
  const view = useAppSelector(selectShopView);
  const selectedCategory = useAppSelector(selectShopSelectedCategory);
  const selectedItemId = useAppSelector(selectShopSelectedItem);
  const quantity = useAppSelector(selectShopQuantity);
  const cart = useAppSelector(selectShopCart);
  const cartOpen = useAppSelector(selectShopCartOpen);

  useNuiEvent<{ visible: boolean; catalog?: { categories: any[]; items: ShopItem[] } }>(
    'setShopVisible',
    (data) => dispatch(setShopVisible(data))
  );

  useNuiEvent<{ ok: boolean }>('clothingPurchaseResult', (data) => {
    if (data?.ok) dispatch(clearCart());
  });

  // ESC ile kapat (mevcut envanter ESC deseniyle ayni ruhta, ayri/bagimsiz).
  useEffect(() => {
    if (!visible) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Escape') fetchNui('bitirim:clothingClose').catch(() => {});
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [visible]);

  const selectedItem = items.find((it) => it.id === selectedItemId) || null;

  // Item secilince previewPed uzerinde dene (satin almaz, sadece gorsel).
  useEffect(() => {
    if (!selectedItem) return;
    fetchNui('bitirim:clothingPreview', {
      slot: selectedItem.slot,
      male: selectedItem.male,
      female: selectedItem.female,
    }).catch(() => {});
  }, [selectedItem]);

  // Karakter gorunumunde surukle-dondur (CharacterPanel.tsx ile AYNI).
  const dragX = useRef<number | null>(null);
  const onViewDown = (e: React.MouseEvent) => {
    dragX.current = e.clientX;
  };
  const onViewMove = (e: React.MouseEvent) => {
    if (dragX.current === null) return;
    const dx = e.clientX - dragX.current;
    if (dx !== 0) {
      dragX.current = e.clientX;
      fetchNui('bitirim:charRotate', { mode: 'drag', value: dx }).catch(() => {});
    }
  };
  const onViewUp = () => {
    dragX.current = null;
  };

  if (!visible) return null;

  const categoryLabel = categories.find((c) => c.id === selectedCategory)?.label || '';
  const gridItems = items.filter((it) => it.category === selectedCategory);
  const cartCount = cart.reduce((sum, line) => sum + line.qty, 0);

  const handleClose = () => fetchNui('bitirim:clothingClose').catch(() => {});

  const handleAddToCart = () => {
    if (!selectedItem) return;
    dispatch(addToCart({ id: selectedItem.id, qty: quantity }));
  };

  return (
    <div className="bx-shop-overlay">
      <div className="bx-shop-window">
        <div className="bx-shop-sidebar">
          {view === 'categories' ? (
            <>
              <div className="bx-shop-header">
                <p className="bx-shop-eyebrow">Shop</p>
                <p className="bx-shop-title">Clothes</p>
              </div>
              <div className="bx-shop-cat-list">
                {categories.map((cat) => {
                  const Icon = CATEGORY_ICONS[cat.id] || IconCap;
                  return (
                    <button
                      type="button"
                      key={cat.id}
                      className="bx-shop-cat-item"
                      onClick={() => dispatch(openCategory(cat.id))}
                    >
                      <span>{cat.label.toUpperCase()}</span>
                      <Icon size={20} />
                    </button>
                  );
                })}
              </div>
            </>
          ) : (
            <>
              <div className="bx-shop-grid-header">
                <button
                  type="button"
                  className="bx-shop-back-btn"
                  onClick={() => dispatch(backToCategories())}
                  title="Kategorilere dön"
                >
                  <IconBack size={18} />
                </button>
                <p className="bx-shop-grid-title">{categoryLabel.toUpperCase()}</p>
                <button
                  type="button"
                  className="bx-shop-cart-icon-btn"
                  onClick={() => dispatch(toggleCart())}
                  title="Sepet"
                >
                  <IconCart size={18} />
                </button>
              </div>
              <div className="bx-shop-grid">
                {gridItems.map((item) => {
                  const Icon = CATEGORY_ICONS[item.category] || IconCap;
                  return (
                    <button
                      type="button"
                      key={item.id}
                      className={'bx-shop-item-thumb' + (selectedItemId === item.id ? ' selected' : '')}
                      onClick={() => dispatch(selectItem(item.id))}
                    >
                      <Icon size={30} />
                      <span className="bx-shop-item-label">{item.label}</span>
                    </button>
                  );
                })}
              </div>
            </>
          )}
        </div>

        <div className="bx-shop-stage">
          <button type="button" className="bx-shop-close-btn" onClick={handleClose}>
            CLOSE <span className="bx-shop-esc">ESC</span>
          </button>

          <div
            className="bx-char-view bx-shop-char-view"
            onMouseDown={onViewDown}
            onMouseMove={onViewMove}
            onMouseUp={onViewUp}
            onMouseLeave={onViewUp}
          />

          <div className="bx-shop-turn-hint">
            <span className="bx-shop-turn-icon" />
            Turn Character
          </div>

          <button type="button" className="bx-shop-cart-badge" onClick={() => dispatch(toggleCart())}>
            <IconCart size={18} />
            {cartCount > 0 && <span className="bx-shop-cart-count">{cartCount}</span>}
          </button>

          {cartOpen && <ClothingShopCart />}

          {selectedItem && (
            <div className="bx-shop-infobar">
              <div className="bx-shop-infobar-main">
                <p className="bx-shop-item-name">{selectedItem.label}</p>
                <p className="bx-shop-item-breadcrumb">Clothing / {categoryLabel}</p>
              </div>
              <div className="bx-shop-qty">
                <button type="button" onClick={() => dispatch(setQuantity(quantity - 1))}>
                  −
                </button>
                <span>{quantity}</span>
                <button type="button" onClick={() => dispatch(setQuantity(quantity + 1))}>
                  +
                </button>
              </div>
              <button type="button" className="bx-shop-addcart-btn" onClick={handleAddToCart}>
                + ADD TO CART <span>${(selectedItem.price * quantity).toLocaleString('tr-TR')}</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default ClothingShop;
