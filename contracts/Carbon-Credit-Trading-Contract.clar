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
(define-constant err-stake-not-found (err u110))
(define-constant err-stake-locked (err u111))
(define-constant err-insufficient-stake-balance (err u112))
(define-constant err-not-authorized-auditor (err u113))
(define-constant err-audit-not-found (err u114))
(define-constant err-audit-already-completed (err u115))
(define-constant err-invalid-audit-status (err u116))
(define-constant err-certificate-not-found (err u117))
(define-constant err-credit-already-audited (err u118))

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
(define-map credit-stakes
    uint
    {
        staker: principal,
        credit-id: uint,
        amount: uint,
        staked-at: uint,
        lock-period: uint,
        reward-rate: uint,
    }
)
(define-map user-stake-balances
    principal
    uint
)

;; === AUDITING SYSTEM DATA STRUCTURES ===
(define-map authorized-auditors
    principal
    {
        authorized-at: uint,
        certifications: (list 10 (string-ascii 32)),
        total-audits: uint,
        reputation-score: uint,
    }
)

(define-map audit-records
    uint
    {
        auditor: principal,
        credit-id: uint,
        initiated-at: uint,
        completed-at: (optional uint),
        status: (string-ascii 16),
        findings: (string-ascii 256),
        verification-score: uint,
        compliance-level: (string-ascii 16),
    }
)

(define-map compliance-certificates
    uint
    {
        credit-id: uint,
        auditor: principal,
        issued-at: uint,
        expiry-date: uint,
        certificate-hash: (string-ascii 64),
        compliance-grade: (string-ascii 2),
        verified: bool,
    }
)

(define-data-var next-credit-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-stake-id uint u1)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)
(define-data-var total-credits-staked uint u0)
(define-data-var next-audit-id uint u1)
(define-data-var next-certificate-id uint u1)
(define-data-var total-audits-completed uint u0)
(define-data-var total-certificates-issued uint u0)

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

(define-public (stake-credits
        (credit-id uint)
        (lock-period uint)
    )
    (let (
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (stake-id (var-get next-stake-id))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (stake-balance (default-to u0 (map-get? user-stake-balances tx-sender)))
            (reward-rate (calculate-reward-rate lock-period))
        )
        (asserts! (is-eq (get owner credit) tx-sender) err-not-authorized)
        (asserts! (not (get retired credit)) err-credit-retired)
        (asserts! (>= user-balance (get amount credit)) err-insufficient-balance)
        (asserts! (> lock-period u0) err-invalid-amount)
        (map-set credit-stakes stake-id {
            staker: tx-sender,
            credit-id: credit-id,
            amount: (get amount credit),
            staked-at: stacks-block-height,
            lock-period: lock-period,
            reward-rate: reward-rate,
        })
        (map-set user-balances tx-sender (- user-balance (get amount credit)))
        (map-set user-stake-balances tx-sender
            (+ stake-balance (get amount credit))
        )
        (var-set next-stake-id (+ stake-id u1))
        (var-set total-credits-staked
            (+ (var-get total-credits-staked) (get amount credit))
        )
        (ok stake-id)
    )
)

(define-public (unstake-credits (stake-id uint))
    (let (
            (stake (unwrap! (map-get? credit-stakes stake-id) err-stake-not-found))
            (unlock-height (+ (get staked-at stake) (get lock-period stake)))
            (user-balance (default-to u0 (map-get? user-balances tx-sender)))
            (stake-balance (default-to u0 (map-get? user-stake-balances tx-sender)))
            (rewards (calculate-staking-rewards stake-id))
        )
        (asserts! (is-eq (get staker stake) tx-sender) err-not-authorized)
        (asserts! (>= stacks-block-height unlock-height) err-stake-locked)
        (asserts! (>= stake-balance (get amount stake))
            err-insufficient-stake-balance
        )
        (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
        (map-delete credit-stakes stake-id)
        (map-set user-balances tx-sender (+ user-balance (get amount stake)))
        (map-set user-stake-balances tx-sender
            (- stake-balance (get amount stake))
        )
        (var-set total-credits-staked
            (- (var-get total-credits-staked) (get amount stake))
        )
        (ok true)
    )
)

(define-public (claim-staking-rewards (stake-id uint))
    (let (
            (stake (unwrap! (map-get? credit-stakes stake-id) err-stake-not-found))
            (rewards (calculate-staking-rewards stake-id))
        )
        (asserts! (is-eq (get staker stake) tx-sender) err-not-authorized)
        (asserts! (> rewards u0) err-invalid-amount)
        (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
        (ok rewards)
    )
)

(define-private (calculate-reward-rate (lock-period uint))
    (if (>= lock-period u52560)
        u10
        (if (>= lock-period u26280)
            u5
            u2
        )
    )
)

(define-private (calculate-staking-rewards (stake-id uint))
    (match (map-get? credit-stakes stake-id)
        stake (let (
                (time-staked (- stacks-block-height (get staked-at stake)))
                (reward-per-block (/ (* (get amount stake) (get reward-rate stake)) u10000))
            )
            (* time-staked reward-per-block)
        )
        u0
    )
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
        total-staked: (var-get total-credits-staked),
        total-active: (- (var-get total-credits-issued) (var-get total-credits-retired)),
        next-credit-id: (var-get next-credit-id),
        next-listing-id: (var-get next-listing-id),
        next-stake-id: (var-get next-stake-id),
        total-audits-completed: (var-get total-audits-completed),
        total-certificates-issued: (var-get total-certificates-issued),
        next-audit-id: (var-get next-audit-id),
        next-certificate-id: (var-get next-certificate-id),
    }
)

(define-read-only (get-stake-info (stake-id uint))
    (map-get? credit-stakes stake-id)
)

(define-read-only (get-user-stake-balance (user principal))
    (default-to u0 (map-get? user-stake-balances user))
)

(define-read-only (get-staking-rewards (stake-id uint))
    (calculate-staking-rewards stake-id)
)

(define-read-only (is-stake-unlocked (stake-id uint))
    (match (map-get? credit-stakes stake-id)
        stake (>= stacks-block-height (+ (get staked-at stake) (get lock-period stake)))
        false
    )
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

;; === AUDITING SYSTEM FUNCTIONS ===

(define-public (authorize-auditor 
        (auditor principal)
        (certifications (list 10 (string-ascii 32)))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-auditors auditor {
            authorized-at: stacks-block-height,
            certifications: certifications,
            total-audits: u0,
            reputation-score: u100,
        })
        (ok true)
    )
)

(define-public (revoke-auditor (auditor principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete authorized-auditors auditor))
    )
)

(define-read-only (is-authorized-auditor (auditor principal))
    (is-some (map-get? authorized-auditors auditor))
)

(define-public (initiate-audit (credit-id uint))
    (let (
            (credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found))
            (audit-id (var-get next-audit-id))
        )
        (asserts! (is-authorized-auditor tx-sender) err-not-authorized-auditor)
        (asserts! (not (get retired credit)) err-credit-retired)
        (asserts! (is-none (get-active-audit-for-credit credit-id)) err-credit-already-audited)
        
        (map-set audit-records audit-id {
            auditor: tx-sender,
            credit-id: credit-id,
            initiated-at: stacks-block-height,
            completed-at: none,
            status: "in-progress",
            findings: "",
            verification-score: u0,
            compliance-level: "",
        })
        (var-set next-audit-id (+ audit-id u1))
        (ok audit-id)
    )
)

(define-public (complete-audit
        (audit-id uint)
        (findings (string-ascii 256))
        (verification-score uint)
        (compliance-level (string-ascii 16))
    )
    (let (
            (audit (unwrap! (map-get? audit-records audit-id) err-audit-not-found))
            (auditor-info (unwrap! (map-get? authorized-auditors tx-sender) err-not-authorized-auditor))
        )
        (asserts! (is-eq (get auditor audit) tx-sender) err-not-authorized)
        (asserts! (is-eq (get status audit) "in-progress") err-audit-already-completed)
        (asserts! (<= verification-score u100) err-invalid-audit-status)
        
        (map-set audit-records audit-id (merge audit {
            completed-at: (some stacks-block-height),
            status: "completed",
            findings: findings,
            verification-score: verification-score,
            compliance-level: compliance-level,
        }))
        
        ;; Update auditor stats
        (map-set authorized-auditors tx-sender (merge auditor-info {
            total-audits: (+ (get total-audits auditor-info) u1),
            reputation-score: (calculate-new-reputation 
                (get reputation-score auditor-info) 
                verification-score
            ),
        }))
        
        (var-set total-audits-completed (+ (var-get total-audits-completed) u1))
        (ok true)
    )
)

(define-public (issue-compliance-certificate
        (audit-id uint)
        (expiry-blocks uint)
        (certificate-hash (string-ascii 64))
        (compliance-grade (string-ascii 2))
    )
    (let (
            (audit (unwrap! (map-get? audit-records audit-id) err-audit-not-found))
            (certificate-id (var-get next-certificate-id))
            (expiry-date (+ stacks-block-height expiry-blocks))
        )
        (asserts! (is-eq (get auditor audit) tx-sender) err-not-authorized)
        (asserts! (is-eq (get status audit) "completed") err-invalid-audit-status)
        (asserts! (>= (get verification-score audit) u70) err-invalid-audit-status)
        
        (map-set compliance-certificates certificate-id {
            credit-id: (get credit-id audit),
            auditor: tx-sender,
            issued-at: stacks-block-height,
            expiry-date: expiry-date,
            certificate-hash: certificate-hash,
            compliance-grade: compliance-grade,
            verified: true,
        })
        
        (var-set next-certificate-id (+ certificate-id u1))
        (var-set total-certificates-issued (+ (var-get total-certificates-issued) u1))
        (ok certificate-id)
    )
)

(define-public (revoke-certificate (certificate-id uint))
    (let (
            (certificate (unwrap! (map-get? compliance-certificates certificate-id) err-certificate-not-found))
        )
        (asserts! (or 
            (is-eq tx-sender contract-owner) 
            (is-eq tx-sender (get auditor certificate))
        ) err-not-authorized)
        
        (map-set compliance-certificates certificate-id 
            (merge certificate { verified: false })
        )
        (ok true)
    )
)

;; === AUDITING READ-ONLY FUNCTIONS ===

(define-read-only (get-auditor-info (auditor principal))
    (map-get? authorized-auditors auditor)
)

(define-read-only (get-audit-record (audit-id uint))
    (map-get? audit-records audit-id)
)

(define-read-only (get-compliance-certificate (certificate-id uint))
    (map-get? compliance-certificates certificate-id)
)

(define-read-only (get-active-audit-for-credit (credit-id uint))
    (let (
            (audit-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
        )
        (find-active-audit-for-credit audit-ids credit-id)
    )
)

(define-read-only (is-certificate-valid (certificate-id uint))
    (match (map-get? compliance-certificates certificate-id)
        certificate (and 
            (get verified certificate)
            (> (get expiry-date certificate) stacks-block-height)
        )
        false
    )
)

(define-read-only (get-audit-statistics)
    {
        total-audits-completed: (var-get total-audits-completed),
        total-certificates-issued: (var-get total-certificates-issued),
        next-audit-id: (var-get next-audit-id),
        next-certificate-id: (var-get next-certificate-id),
    }
)

(define-read-only (get-credit-audit-history (credit-id uint))
    (list 
        (get-audit-with-id u1 credit-id)
        (get-audit-with-id u2 credit-id)
        (get-audit-with-id u3 credit-id)
        (get-audit-with-id u4 credit-id)
        (get-audit-with-id u5 credit-id)
    )
)

;; === PRIVATE HELPER FUNCTIONS ===

(define-private (calculate-new-reputation (current-score uint) (verification-score uint))
    (let (
            (weighted-score (/ (+ (* current-score u4) verification-score) u5))
        )
        (if (> weighted-score u100) u100 weighted-score)
    )
)

(define-private (find-active-audit-for-credit (audit-ids (list 10 uint)) (target-credit-id uint))
    (let (
            (active-audits (filter is-active-audit-for-target 
                (map get-audit-with-target-id 
                    (map combine-ids audit-ids (list target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id target-credit-id))
                )
            ))
        )
        (if (> (len active-audits) u0)
            (some (get audit-id (unwrap-panic (element-at? active-audits u0))))
            none
        )
    )
)

(define-private (combine-ids (audit-id uint) (credit-id uint))
    { audit-id: audit-id, credit-id: credit-id }
)

(define-private (get-audit-with-target-id (ids { audit-id: uint, credit-id: uint }))
    (match (map-get? audit-records (get audit-id ids))
        audit (merge audit { audit-id: (get audit-id ids), target-credit-id: (get credit-id ids) })
        {
            audit-id: u0,
            target-credit-id: (get credit-id ids),
            auditor: contract-owner,
            credit-id: u0,
            initiated-at: u0,
            completed-at: none,
            status: "",
            findings: "",
            verification-score: u0,
            compliance-level: "",
        }
    )
)

(define-private (is-active-audit-for-target (audit {
    audit-id: uint,
    target-credit-id: uint,
    auditor: principal,
    credit-id: uint,
    initiated-at: uint,
    completed-at: (optional uint),
    status: (string-ascii 16),
    findings: (string-ascii 256),
    verification-score: uint,
    compliance-level: (string-ascii 16),
}))
    (and
        (> (get audit-id audit) u0)
        (is-eq (get credit-id audit) (get target-credit-id audit))
        (is-eq (get status audit) "in-progress")
    )
)

(define-private (get-audit-with-id (audit-id uint) (target-credit-id uint))
    (match (map-get? audit-records audit-id)
        audit (if (is-eq (get credit-id audit) target-credit-id)
            (some (merge audit { audit-id: audit-id }))
            none
        )
        none
    )
)

(define-private (is-credit-audit (audit-option (optional {
    audit-id: uint,
    auditor: principal,
    credit-id: uint,
    initiated-at: uint,
    completed-at: (optional uint),
    status: (string-ascii 16),
    findings: (string-ascii 256),
    verification-score: uint,
    compliance-level: (string-ascii 16),
})))
    (is-some audit-option)
)

(map-set authorized-issuers contract-owner true)
