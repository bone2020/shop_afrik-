import { HttpsError } from 'firebase-functions/v2/https';
import { Money } from '../types';

// The one seam to the QR Wallet platform account. Every money move Shop Afrik
// instructs goes through this file, with an explicit currency (on `Money`)
// and an idempotency key.
//
// Inert until the merchant API contract is agreed and staging exists: every
// call throws so callers surface a real failure. Never simulate success here.

export interface BuyerMoveInput {
  orderId: string;
  buyerWalletId: string;
  amount: Money;
  idempotencyKey: string;
}

export interface CaptureHoldInput {
  orderId: string;
  amount: Money;
  idempotencyKey: string;
}

export interface SettleInput {
  orderId: string;
  sellerId: string;
  /** Seller's gross share; leaves escrow. */
  gross: Money;
  /** Shop Afrik's cut of [gross]; the rest goes to payable. */
  commission: Money;
  idempotencyKey: string;
}

export interface PayoutInput {
  settlementId: string;
  sellerWalletId: string;
  amount: Money;
  idempotencyKey: string;
}

export interface PlatformBalances {
  escrow: Money;
  payable: Money;
  commission: Money;
}

function notConnected(operation: string): never {
  throw new HttpsError(
    'unavailable',
    `Payments are not connected yet (QR Wallet ${operation}).`,
  );
}

/** Pay now: buyer wallet → escrow. Returns the QR Wallet transaction id. */
export async function capture(input: BuyerMoveInput): Promise<string> {
  void input;
  return notConnected('capture');
}

/** Pay on delivery: authorization hold on the buyer wallet. */
export async function hold(input: BuyerMoveInput): Promise<string> {
  void input;
  return notConnected('hold');
}

/** Pay on delivery: capture an existing hold into escrow. */
export async function captureHold(input: CaptureHoldInput): Promise<string> {
  void input;
  return notConnected('captureHold');
}

/** Release an uncaptured hold back to the buyer. */
export async function releaseHold(input: BuyerMoveInput): Promise<string> {
  void input;
  return notConnected('releaseHold');
}

/** Escrow → buyer wallet (refund or cancellation). */
export async function refundFromEscrow(input: BuyerMoveInput): Promise<string> {
  void input;
  return notConnected('refundFromEscrow');
}

/** Escrow → payable (net) + commission. */
export async function settleToPayable(input: SettleInput): Promise<string> {
  void input;
  return notConnected('settleToPayable');
}

/** Payable → seller wallet. Returns the payout id. */
export async function payoutToSeller(input: PayoutInput): Promise<string> {
  void input;
  return notConnected('payoutToSeller');
}

/** Reads the platform account's three buckets for one currency. */
export async function getBalances(currency: string): Promise<PlatformBalances> {
  void currency;
  return notConnected('getBalances');
}
