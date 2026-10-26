import { HttpsError } from 'firebase-functions/v2/https';
import { Money } from '../types';
import { mockBonsPay } from './mockBonsPay';

// The one seam to the QR Wallet (BonsPay) platform account. Every money move
// Shop Afrik instructs goes through this file, with an explicit currency (on
// `Money`) and an idempotency key.
//
// Which backend answers is chosen per call by QR_WALLET_MODE:
//   - unset / "inert" (default, and the only option in production): every
//     call throws so callers surface a real failure. Never simulate success.
//   - "mock": the fake BonsPay in mockBonsPay.ts, for emulator tests and
//     kartafrik-staging until bonspay-staging is ready (SA-023). It refuses
//     to run in any project that is not a demo or staging project.

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

/** The operations a BonsPay backend must provide. */
export interface QrWalletBackend {
  capture(input: BuyerMoveInput): Promise<string>;
  hold(input: BuyerMoveInput): Promise<string>;
  captureHold(input: CaptureHoldInput): Promise<string>;
  releaseHold(input: BuyerMoveInput): Promise<string>;
  refundFromEscrow(input: BuyerMoveInput): Promise<string>;
  settleToPayable(input: SettleInput): Promise<string>;
  payoutToSeller(input: PayoutInput): Promise<string>;
  getBalances(currency: string): Promise<PlatformBalances>;
}

function notConnected(operation: string): never {
  throw new HttpsError(
    'unavailable',
    `Payments are not connected yet (QR Wallet ${operation}).`,
  );
}

const inert: QrWalletBackend = {
  capture: async () => notConnected('capture'),
  hold: async () => notConnected('hold'),
  captureHold: async () => notConnected('captureHold'),
  releaseHold: async () => notConnected('releaseHold'),
  refundFromEscrow: async () => notConnected('refundFromEscrow'),
  settleToPayable: async () => notConnected('settleToPayable'),
  payoutToSeller: async () => notConnected('payoutToSeller'),
  getBalances: async () => notConnected('getBalances'),
};

/** Projects where the fake BonsPay may run: emulator demos and staging. */
export function mockAllowedFor(projectId: string | undefined): boolean {
  return !!projectId && (projectId.startsWith('demo-') || projectId.includes('staging'));
}

function backend(): QrWalletBackend {
  if (process.env.QR_WALLET_MODE !== 'mock') return inert;
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!mockAllowedFor(project)) {
    throw new HttpsError(
      'failed-precondition',
      `The fake BonsPay cannot run in project ${project}.`,
    );
  }
  return mockBonsPay;
}

/** Pay now: buyer wallet → escrow. Returns the QR Wallet transaction id. */
export async function capture(input: BuyerMoveInput): Promise<string> {
  return backend().capture(input);
}

/** Pay on delivery: authorization hold on the buyer wallet. */
export async function hold(input: BuyerMoveInput): Promise<string> {
  return backend().hold(input);
}

/** Pay on delivery: capture an existing hold into escrow. */
export async function captureHold(input: CaptureHoldInput): Promise<string> {
  return backend().captureHold(input);
}

/** Release an uncaptured hold back to the buyer. */
export async function releaseHold(input: BuyerMoveInput): Promise<string> {
  return backend().releaseHold(input);
}

/** Escrow → buyer wallet (refund or cancellation). */
export async function refundFromEscrow(input: BuyerMoveInput): Promise<string> {
  return backend().refundFromEscrow(input);
}

/** Escrow → payable (net) + commission. */
export async function settleToPayable(input: SettleInput): Promise<string> {
  return backend().settleToPayable(input);
}

/** Payable → seller wallet. Returns the payout id. */
export async function payoutToSeller(input: PayoutInput): Promise<string> {
  return backend().payoutToSeller(input);
}

/** Reads the platform account's three buckets for one currency. */
export async function getBalances(currency: string): Promise<PlatformBalances> {
  return backend().getBalances(currency);
}
