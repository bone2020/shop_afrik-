import { mockAllowedFor } from '../../src/lib/qrWallet';

describe('fake BonsPay guard', () => {
  it('runs only in demo or staging projects', () => {
    expect(mockAllowedFor('demo-shop-afrik')).toBe(true);
    expect(mockAllowedFor('kartafrik-staging')).toBe(true);
    expect(mockAllowedFor('shop-afrik')).toBe(false);
    expect(mockAllowedFor(undefined)).toBe(false);
  });
});
