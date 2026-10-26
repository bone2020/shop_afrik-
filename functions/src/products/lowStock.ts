import { notify } from '../lib/notify';
import { StockChange } from '../orders/stockReservation';

/**
 * Tells sellers when a sale takes a product to its low-stock level or sells
 * it out (SA-067). Only crossings notify, so each level is announced once
 * per drop.
 */
export async function notifyLowStock(changes: StockChange[]): Promise<void> {
  for (const c of changes) {
    if (c.after <= 0) {
      await notify({
        recipientId: c.sellerId,
        audience: 'seller',
        title: 'Sold out',
        body: `${c.title} is sold out. Add stock to keep selling it.`,
        type: 'low_stock',
        deepLink: `/seller/products/${c.productId}`,
      });
    } else if (c.threshold != null && c.before > c.threshold && c.after <= c.threshold) {
      await notify({
        recipientId: c.sellerId,
        audience: 'seller',
        title: 'Low stock',
        body: `Only ${c.after} left of ${c.title}.`,
        type: 'low_stock',
        deepLink: `/seller/products/${c.productId}`,
      });
    }
  }
}
