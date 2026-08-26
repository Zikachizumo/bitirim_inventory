import React from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import {
  CartLine,
  ShopItem,
  removeFromCart,
  selectShopCart,
  selectShopItems,
} from '../../store/clothingShop';
import { fetchNui } from '../../utils/fetchNui';
import { IconClose } from './BitirimIcons';

/**
 * Bitirim — kıyafet mağazası sepet paneli.
 * Sepet rozetinin altında açılan küçük özet: satır listesi + sil + toplam + checkout.
 */
const ClothingShopCart: React.FC = () => {
  const dispatch = useAppDispatch();
  const cart = useAppSelector(selectShopCart);
  const items = useAppSelector(selectShopItems);

  const itemsById = new Map<string, ShopItem>(items.map((it) => [it.id, it]));

  const lines: Array<{ line: CartLine; item: ShopItem }> = cart
    .map((line) => {
      const item = itemsById.get(line.id);
      return item ? { line, item } : null;
    })
    .filter((x): x is { line: CartLine; item: ShopItem } => x !== null);

  const total = lines.reduce((sum, { line, item }) => sum + line.qty * item.price, 0);

  const handleCheckout = () => {
    if (lines.length === 0) return;
    fetchNui('bitirim:clothingCheckout', { cart }).catch(() => {});
  };

  return (
    <div className="bx-shop-cart-panel">
      <p className="bx-panel-title">Shopping Cart</p>
      {lines.length === 0 ? (
        <p className="bx-shop-cart-empty">There are no items in the shopping cart</p>
      ) : (
        <>
          <div className="bx-shop-cart-lines">
            {lines.map(({ line, item }) => (
              <div className="bx-shop-cart-line" key={line.id}>
                <span className="bx-shop-cart-line-label">
                  {item.label} × {line.qty}
                </span>
                <span className="bx-shop-cart-line-price">${(item.price * line.qty).toLocaleString('tr-TR')}</span>
                <button
                  type="button"
                  className="bx-shop-cart-line-remove"
                  onClick={() => dispatch(removeFromCart(line.id))}
                  title="Sepetten çıkar"
                >
                  <IconClose size={12} />
                </button>
              </div>
            ))}
          </div>
          <div className="bx-shop-cart-total">
            <span>Total</span>
            <span>${total.toLocaleString('tr-TR')}</span>
          </div>
          <button type="button" className="bx-shop-checkout-btn" onClick={handleCheckout}>
            CHECKOUT
          </button>
        </>
      )}
    </div>
  );
};

export default ClothingShopCart;
