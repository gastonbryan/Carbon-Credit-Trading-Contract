(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-credit-not-found (err u104))
(define-constant err-credit-retired (err u105))
(define-constant err-invalid-price (err u106))
(define-constant err-listing-not-found (err u107))
(define-constant err-cannot-buy-own-listing (err u108))
(define-constant err-listing-expired (err u109))

(define-map authorized-issuers
    principal
    bool
)
(define-map carbon-credits
    uint
    {
        issuer: principal,
        owner: principal,
        amount: uint,
        project-id: (string-ascii 64),
        vintage-year: uint,
        retired: bool,
        created-at: uint,
    }
)
(define-map user-balances
    principal
    uint
)
(define-map project-totals
    (string-ascii 64)
    uint
)
(define-map marketplace-listings
    uint
    {
        seller: principal,
        credit-id: uint,
        price: uint,
        expires-at: uint,
        active: bool,
    }
)

(define-data-var next-credit-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)

(define-public (authorize-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-issuers issuer true))
    )
)

(define-public (revoke-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete authorized-issuers issuer))
    )
)

(define-read-only (is-authorized-issuer (issuer principal))
    (default-to false (map-get? authorized-issuers issuer))
)

(define-public (issue-credits
        (amount uint)
        (project-id (string-ascii 64))
        (vintage-year uint)
    )
    (let (
            (credit-id (var-get next-credit-id))
            (current-total (default-to u0 (map-get? project-totals project-id)))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (is-authorized-issuer tx-sender) err-not-authorized)
        (asserts! (> amount u0) err-invalid-amount)
        (map-set carbon-credits credit-id {
            issuer: tx-sender,
            owner: tx-sender,
            amount: amount,
            project-id: project-id,
            vintage-year: vintage-year,
            retired: false,
            created-at: stacks-block-height,
        })
        (map-set project-totals project-id (+ current-total amount))
        (map-set user-balances tx-sender (+ user-balance amount))
        (var-set next-credit-id (+ credit-id u1))
        (var-set total-credits-issued (+ (var-get total-credits-issued) amount))
        (ok credit-id)
    )
)

(define-public (transfer-credits
        (credit-id uint)
        (recipient principal)
    )
    (let (
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (sender-balance (default-to u0 (map-get? user-balances tx-sender)))
            (recipient-balance (default-to u0 (map-get? user-balances recipient)))
        )
        (asserts! (is-eq (get owner credit) tx-sender) err-not-authorized)
        (asserts! (not (get retired credit)) err-credit-retired)
        (asserts! (>= sender-balance (get amount credit))
            err-insufficient-balance
        )
        (map-set carbon-credits credit-id (merge credit { owner: recipient }))
        (map-set user-balances tx-sender (- sender-balance (get amount credit)))
        (map-set user-balances recipient
            (+ recipient-balance (get amount credit))
        )
        (ok true)
    )
)

(define-public (retire-credits (credit-id uint))
    (let (
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (is-eq (get owner credit) tx-sender) err-not-authorized)
        (asserts! (not (get retired credit)) err-credit-retired)
        (asserts! (>= user-balance (get amount credit)) err-insufficient-balance)
        (map-set carbon-credits credit-id (merge credit { retired: true }))
        (map-set user-balances tx-sender (- user-balance (get amount credit)))
        (var-set total-credits-retired
            (+ (var-get total-credits-retired) (get amount credit))
        )
        (ok true)
    )
)

(define-public (create-listing
        (credit-id uint)
        (price uint)
        (duration uint)
    )
    (let (
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (listing-id (var-get next-listing-id))
            (expires-at (+ stacks-block-height duration))
        )
        (asserts! (is-eq (get owner credit) tx-sender) err-not-authorized)
        (asserts! (not (get retired credit)) err-credit-retired)
        (asserts! (> price u0) err-invalid-price)
        (map-set marketplace-listings listing-id {
            seller: tx-sender,
            credit-id: credit-id,
            price: price,
            expires-at: expires-at,
            active: true,
        })
        (var-set next-listing-id (+ listing-id u1))
        (ok listing-id)
    )
)

(define-public (cancel-listing (listing-id uint))
    (let ((listing (unwrap! (map-get? marketplace-listings listing-id) err-listing-not-found)))
        (asserts! (is-eq (get seller listing) tx-sender) err-not-authorized)
        (asserts! (get active listing) err-listing-not-found)
        (map-set marketplace-listings listing-id
            (merge listing { active: false })
        )
        (ok true)
    )
)

(define-public (buy-credits (listing-id uint))
    (let (
            (listing (unwrap! (map-get? marketplace-listings listing-id)
                err-listing-not-found
            ))
            (credit-id (get credit-id listing))
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (buyer-balance (default-to u0 (map-get? user-balances tx-sender)))
            (seller-balance (default-to u0 (map-get? user-balances (get seller listing))))
        )
        (asserts! (get active listing) err-listing-not-found)
        (asserts! (<= stacks-block-height (get expires-at listing))
            err-listing-expired
        )
        (asserts! (not (is-eq tx-sender (get seller listing)))
            err-cannot-buy-own-listing
        )
        (asserts! (not (get retired credit)) err-credit-retired)
        (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
        (map-set carbon-credits credit-id (merge credit { owner: tx-sender }))
        (map-set user-balances tx-sender (+ buyer-balance (get amount credit)))
        (map-set user-balances (get seller listing)
            (- seller-balance (get amount credit))
        )
        (map-set marketplace-listings listing-id
            (merge listing { active: false })
        )
        (ok credit-id)
    )
)

(define-public (batch-transfer (transfers (list 50 {
    credit-id: uint,
    recipient: principal,
})))
    (ok (map transfer-credits-batch transfers))
)

(define-private (transfer-credits-batch (transfer {
    credit-id: uint,
    recipient: principal,
}))
    (transfer-credits (get credit-id transfer) (get recipient transfer))
)

(define-public (batch-retire (credit-ids (list 50 uint)))
    (ok (map retire-credits credit-ids))
)

(define-read-only (get-credit-info (credit-id uint))
    (map-get? carbon-credits credit-id)
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-project-total (project-id (string-ascii 64)))
    (default-to u0 (map-get? project-totals project-id))
)

(define-read-only (get-listing-info (listing-id uint))
    (map-get? marketplace-listings listing-id)
)

(define-read-only (get-contract-stats)
    {
        total-issued: (var-get total-credits-issued),
        total-retired: (var-get total-credits-retired),
        total-active: (- (var-get total-credits-issued) (var-get total-credits-retired)),
        next-credit-id: (var-get next-credit-id),
        next-listing-id: (var-get next-listing-id),
    }
)

(define-read-only (is-credit-available (credit-id uint))
    (match (map-get? carbon-credits credit-id)
        credit (and (not (get retired credit)) true)
        false
    )
)

(define-read-only (get-active-listings-by-seller (seller principal))
    (let ((listing-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
        (filter is-active-seller-listing (map get-listing-with-id listing-ids))
    )
)

(define-private (get-listing-with-id (listing-id uint))
    (match (map-get? marketplace-listings listing-id)
        listing (merge listing { listing-id: listing-id })
        {
            listing-id: u0,
            seller: contract-owner,
            credit-id: u0,
            price: u0,
            expires-at: u0,
            active: false,
        }
    )
)

(define-private (is-active-seller-listing (listing {
    listing-id: uint,
    seller: principal,
    credit-id: uint,
    price: uint,
    expires-at: uint,
    active: bool,
}))
    (and
        (get active listing)
        (> (get listing-id listing) u0)
        (<= stacks-block-height (get expires-at listing))
    )
)

(define-read-only (get-credit-price-history (credit-id uint))
    (let ((listing-ids (list u1 u2 u3 u4 u5)))
        (filter is-credit-listing (map get-listing-with-id listing-ids))
    )
)

(define-private (is-credit-listing (listing {
    listing-id: uint,
    seller: principal,
    credit-id: uint,
    price: uint,
    expires-at: uint,
    active: bool,
}))
    (is-eq (get credit-id listing) (get credit-id listing))
)

(define-read-only (calculate-carbon-footprint
        (amount uint)
        (efficiency-factor uint)
    )
    (/ (* amount efficiency-factor) u100)
)

(define-read-only (get-vintage-credits (vintage-year uint))
    (let ((credit-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
        (filter is-vintage-year (map get-credit-with-id credit-ids))
    )
)

(define-private (get-credit-with-id (credit-id uint))
    (match (map-get? carbon-credits credit-id)
        credit (merge credit { credit-id: credit-id })
        {
            credit-id: u0,
            issuer: contract-owner,
            owner: contract-owner,
            amount: u0,
            project-id: "",
            vintage-year: u0,
            retired: false,
            created-at: u0,
        }
    )
)

(define-private (is-vintage-year (credit {
    credit-id: uint,
    issuer: principal,
    owner: principal,
    amount: uint,
    project-id: (string-ascii 64),
    vintage-year: uint,
    retired: bool,
    created-at: uint,
}))
    (and
        (> (get credit-id credit) u0)
        (not (get retired credit))
    )
)

(map-set authorized-issuers contract-owner true)
