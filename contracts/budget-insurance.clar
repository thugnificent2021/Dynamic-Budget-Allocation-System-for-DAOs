(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INSUFFICIENT-FUNDS (err u201))
(define-constant ERR-INVALID-CLAIM (err u202))
(define-constant ERR-CLAIM-EXISTS (err u203))
(define-constant ERR-INVALID-COVERAGE (err u204))
(define-constant ERR-VOTING-PERIOD-ACTIVE (err u205))
(define-constant ERR-CLAIM-EXPIRED (err u206))

(define-constant INSURANCE-FEE-RATE u3)
(define-constant CLAIM-VOTING-PERIOD u50)
(define-constant MIN-COVERAGE-RATIO u20)
(define-constant MAX-COVERAGE-RATIO u80)
(define-constant CLAIM-EXPIRY-PERIOD u200)

(define-data-var insurance-pool-balance uint u0)
(define-data-var total-coverage-amount uint u0)
(define-data-var claim-counter uint u0)
(define-data-var contract-owner principal tx-sender)

(define-map insurance-policies
    principal
    {coverage-amount: uint,
     premium-paid: uint,
     coverage-ratio: uint,
     active: bool,
     last-payment: uint})

(define-map insurance-claims
    uint
    {claimant: principal,
     amount: uint,
     reason: (string-ascii 100),
     evidence-hash: (string-ascii 64),
     status: (string-ascii 20),
     submission-time: uint,
     voting-end: uint,
     yes-votes: uint,
     no-votes: uint,
     processed: bool})

(define-map claim-votes
    {claim-id: uint, voter: principal}
    bool)

(define-map risk-assessments
    principal
    {risk-score: uint,
     last-assessment: uint,
     factors: (list 5 (string-ascii 30))})

(define-map premium-calculations
    principal
    {base-rate: uint,
     risk-multiplier: uint,
     coverage-discount: uint,
     final-premium: uint})

(define-public (create-insurance-policy (coverage-amount uint) (coverage-ratio uint))
    (begin
        (asserts! (and (>= coverage-ratio MIN-COVERAGE-RATIO) 
                       (<= coverage-ratio MAX-COVERAGE-RATIO)) ERR-INVALID-COVERAGE)
        
        (let ((premium (/ (* coverage-amount INSURANCE-FEE-RATE coverage-ratio) u10000)))
            (asserts! (>= (get balance (unwrap! (contract-call? .budget-manager get-project-budget tx-sender) ERR-NOT-AUTHORIZED)) premium) ERR-INSUFFICIENT-FUNDS)
            
            (unwrap! (contract-call? .budget-manager record-budget-usage premium) ERR-INSUFFICIENT-FUNDS)
            
            (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) premium))
            (var-set total-coverage-amount (+ (var-get total-coverage-amount) coverage-amount))
            
            (map-set insurance-policies tx-sender
                {coverage-amount: coverage-amount,
                 premium-paid: premium,
                 coverage-ratio: coverage-ratio,
                 active: true,
                 last-payment: block-height})
            
            (ok true))))

(define-public (submit-insurance-claim (amount uint) (reason (string-ascii 100)) (evidence-hash (string-ascii 64)))
    (let ((policy (unwrap! (map-get? insurance-policies tx-sender) ERR-NOT-AUTHORIZED))
          (claim-id (var-get claim-counter)))
        
        (asserts! (get active policy) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (/ (* (get coverage-amount policy) (get coverage-ratio policy)) u100)) ERR-INVALID-CLAIM)
        (asserts! (is-none (map-get? insurance-claims claim-id)) ERR-CLAIM-EXISTS)
        
        (map-set insurance-claims claim-id
            {claimant: tx-sender,
             amount: amount,
             reason: reason,
             evidence-hash: evidence-hash,
             status: "pending",
             submission-time: block-height,
             voting-end: (+ block-height CLAIM-VOTING-PERIOD),
             yes-votes: u0,
             no-votes: u0,
             processed: false})
        
        (var-set claim-counter (+ claim-id u1))
        (ok claim-id)))

(define-public (vote-on-claim (claim-id uint) (approve bool))
    (let ((claim-data (unwrap! (map-get? insurance-claims claim-id) ERR-INVALID-CLAIM))
          (voter-policy (unwrap! (map-get? insurance-policies tx-sender) ERR-NOT-AUTHORIZED)))
        
        (asserts! (get active voter-policy) ERR-NOT-AUTHORIZED)
        (asserts! (<= block-height (get voting-end claim-data)) ERR-VOTING-PERIOD-ACTIVE)
        (asserts! (is-none (map-get? claim-votes {claim-id: claim-id, voter: tx-sender})) ERR-NOT-AUTHORIZED)
        
        (map-set claim-votes {claim-id: claim-id, voter: tx-sender} approve)
        
        (map-set insurance-claims claim-id
            (merge claim-data
                (if approve
                    {yes-votes: (+ (get yes-votes claim-data) u1), no-votes: (get no-votes claim-data)}
                    {yes-votes: (get yes-votes claim-data), no-votes: (+ (get no-votes claim-data) u1)})))
        
        (ok true)))

(define-public (process-claim (claim-id uint))
    (let ((claim-data (unwrap! (map-get? insurance-claims claim-id) ERR-INVALID-CLAIM)))
        
        (asserts! (> block-height (get voting-end claim-data)) ERR-VOTING-PERIOD-ACTIVE)
        (asserts! (not (get processed claim-data)) ERR-INVALID-CLAIM)
        (asserts! (< (- block-height (get submission-time claim-data)) CLAIM-EXPIRY-PERIOD) ERR-CLAIM-EXPIRED)
        
        (let ((total-votes (+ (get yes-votes claim-data) (get no-votes claim-data)))
              (approval-threshold (/ total-votes u2)))
            
            (if (> (get yes-votes claim-data) approval-threshold)
                (begin
                    (asserts! (>= (var-get insurance-pool-balance) (get amount claim-data)) ERR-INSUFFICIENT-FUNDS)
                    
                    (var-set insurance-pool-balance (- (var-get insurance-pool-balance) (get amount claim-data)))
                    
                    (unwrap! (contract-call? .budget-manager allocate-budget 
                                           (get claimant claim-data) 
                                           (get amount claim-data) 
                                           u100) ERR-INSUFFICIENT-FUNDS)
                    
                    (map-set insurance-claims claim-id
                        (merge claim-data {status: "approved", processed: true}))
                    
                    (ok "approved"))
                (begin
                    (map-set insurance-claims claim-id
                        (merge claim-data {status: "rejected", processed: true}))
                    
                    (ok "rejected"))))))

(define-public (assess-project-risk (project principal) (risk-score uint) (risk-factors (list 5 (string-ascii 30))))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= risk-score u100) ERR-INVALID-CLAIM)
        
        (map-set risk-assessments project
            {risk-score: risk-score,
             last-assessment: block-height,
             factors: risk-factors})
        
        (ok true)))

(define-public (calculate-premium (project principal) (coverage-amount uint))
    (let ((risk-data (default-to {risk-score: u50, last-assessment: u0, factors: (list)} 
                                 (map-get? risk-assessments project)))
          (base-rate INSURANCE-FEE-RATE)
          (risk-multiplier (/ (get risk-score risk-data) u10))
          (coverage-discount (if (> coverage-amount u10000) u90 u100)))
        
        (let ((final-premium (/ (* (* coverage-amount base-rate) risk-multiplier coverage-discount) u100000)))
            
            (map-set premium-calculations project
                {base-rate: base-rate,
                 risk-multiplier: risk-multiplier,
                 coverage-discount: coverage-discount,
                 final-premium: final-premium})
            
            (ok final-premium))))

(define-public (emergency-fund-contribution (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) amount))
        (ok true)))

(define-public (deactivate-policy)
    (let ((policy (unwrap! (map-get? insurance-policies tx-sender) ERR-NOT-AUTHORIZED)))
        (map-set insurance-policies tx-sender
            (merge policy {active: false}))
        (var-set total-coverage-amount (- (var-get total-coverage-amount) (get coverage-amount policy)))
        (ok true)))

(define-read-only (get-insurance-policy (project principal))
    (map-get? insurance-policies project))

(define-read-only (get-claim-details (claim-id uint))
    (map-get? insurance-claims claim-id))

(define-read-only (get-pool-balance)
    (var-get insurance-pool-balance))

(define-read-only (get-total-coverage)
    (var-get total-coverage-amount))

(define-read-only (get-risk-assessment (project principal))
    (map-get? risk-assessments project))

(define-read-only (get-premium-calculation (project principal))
    (map-get? premium-calculations project))

(define-read-only (has-voted-on-claim (claim-id uint) (voter principal))
    (is-some (map-get? claim-votes {claim-id: claim-id, voter: voter})))

(define-read-only (get-pool-utilization-ratio)
    (if (> (var-get insurance-pool-balance) u0)
        (/ (* (var-get total-coverage-amount) u100) (var-get insurance-pool-balance))
        u0))
