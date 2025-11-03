# 🧾 Configurable Royalty System

## Overview

Enables platform operators to capture a percentage cut of marketplace sales via configurable basis points (bps). Buyers can opt into royalty-enabled purchases while preserving the original `buy-credits` flow.

## What's Inside

### State Variables
- `royalty-admin` — principal with permission to configure royalty settings (defaults to contract owner)
- `royalty-bps` — royalty percentage in basis points (0-10000 = 0%-100%)
- `royalty-recipient` — principal receiving royalty payments

### Public Functions

#### Configuration (Admin-Only)
```clarity
(set-royalty-bps (new-bps uint))
(set-royalty-recipient (new-recipient principal))
(set-royalty-admin (new-admin principal))
```

#### Purchase Flow
```clarity
(buy-credits-with-royalty (listing-id uint))
```
Mirrors `buy-credits` but splits payment:
- Seller receives `price - royalty`
- Royalty recipient receives `(price * royalty-bps) / 10000`

### Read-Only Functions
```clarity
(get-royalty-admin)
(get-royalty-bps)
(get-royalty-recipient)
(calculate-royalty (amount uint))
```

## Usage Example

```clarity
;; Set 5% royalty (500 bps)
(contract-call? .Carbon-Credit-Trading-Contract set-royalty-bps u500)

;; Configure recipient
(contract-call? .Carbon-Credit-Trading-Contract set-royalty-recipient 'ST1...)

;; Buy with royalty applied
(contract-call? .Carbon-Credit-Trading-Contract buy-credits-with-royalty u1)
```

## Technical Details

- **Non-Breaking**: Original `buy-credits` unchanged
- **Validation**: Royalty must be ≤ 10000 bps (100%)
- **Zero-Royalty Safe**: If `royalty-bps = 0`, no royalty transfer occurs
- **Admin Control**: All setters restricted to `royalty-admin`

## Developer Experience

✅ `clarinet check` — compiles without errors  
✅ Independent test suite passes  
✅ Variables defined before use  
✅ Clean code, no comments or complexity

## Integration Steps

1. Deploy contract
2. Call `set-royalty-bps` with desired percentage
3. Call `set-royalty-recipient` with platform wallet
4. Users call `buy-credits-with-royalty` instead of `buy-credits`
5. Monitor royalty revenue via blockchain explorer
