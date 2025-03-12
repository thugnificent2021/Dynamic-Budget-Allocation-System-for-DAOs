;; Dynamic Budget Allocation System

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))

;; Data vars
(define-data-var treasury-balance uint u0)
(define-data-var total-allocations uint u0)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map budgets 
    principal 
    {balance: uint, performance-score: uint})

;; Public functions
(define-public (initialize-treasury (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set treasury-balance amount)
        (ok true)))
(define-public (allocate-budget (project principal) (amount uint) (initial-score uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR-INVALID-AMOUNT)
        (map-set budgets project {balance: amount, performance-score: initial-score})
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (var-set total-allocations (+ (var-get total-allocations) amount))
        (ok true)))

;; Read-only functions
(define-read-only (get-project-budget (project principal))
    (map-get? budgets project))

(define-read-only (get-treasury-balance)
    (var-get treasury-balance))


(define-constant ERR-INSUFFICIENT-BALANCE (err u102))

(define-public (withdraw-budget (amount uint))
    (let ((current-budget (unwrap! (get-project-budget tx-sender) ERR-NOT-AUTHORIZED)))
        (asserts! (<= amount (get balance current-budget)) ERR-INSUFFICIENT-BALANCE)
        (map-set budgets tx-sender 
            {balance: (- (get balance current-budget) amount),
             performance-score: (get performance-score current-budget)})
        (ok true)))



(define-constant ERR-INVALID-SCORE (err u103))

(define-public (update-performance-score (project principal) (new-score uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-score u100) ERR-INVALID-SCORE)
        (let ((current-budget (unwrap! (get-project-budget project) ERR-NOT-AUTHORIZED)))
            (map-set budgets project 
                {balance: (get balance current-budget),
                 performance-score: new-score})
            (ok true))))


(define-public (transfer-budget (to principal) (amount uint))
    (let ((sender-budget (unwrap! (get-project-budget tx-sender) ERR-NOT-AUTHORIZED))
          (receiver-budget (unwrap! (get-project-budget to) ERR-NOT-AUTHORIZED)))
        (asserts! (<= amount (get balance sender-budget)) ERR-INSUFFICIENT-BALANCE)
        (map-set budgets tx-sender 
            {balance: (- (get balance sender-budget) amount),
             performance-score: (get performance-score sender-budget)})
        (map-set budgets to 
            {balance: (+ (get balance receiver-budget) amount),
             performance-score: (get performance-score receiver-budget)})
        (ok true)))



(define-data-var emergency-fund uint u0)
(define-constant EMERGENCY-THRESHOLD u1000)

(define-public (allocate-to-emergency-fund (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR-INVALID-AMOUNT)
        (var-set emergency-fund (+ (var-get emergency-fund) amount))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)))


(define-map budget-expiration principal uint)

(define-public (set-budget-expiration (project principal) (blocks uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set budget-expiration project (+ block-height blocks))
        (ok true)))

(define-read-only (is-budget-expired (project principal))
    (let ((expiration (default-to u0 (map-get? budget-expiration project))))
        (> block-height expiration)))


(define-map budget-proposals
    uint
    {proposer: principal, 
     amount: uint, 
     description: (string-ascii 50), 
     approved: bool})

(define-data-var proposal-counter uint u0)

(define-public (submit-budget-proposal (amount uint) (description (string-ascii 50)))
    (let ((proposal-id (var-get proposal-counter)))
        (map-set budget-proposals proposal-id
            {proposer: tx-sender,
             amount: amount,
             description: description,
             approved: false})
        (var-set proposal-counter (+ proposal-id u1))
        (ok proposal-id)))



;; Add these definitions
(define-map budget-categories 
    principal 
    (string-ascii 20))

(define-public (set-budget-category (project principal) (category (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set budget-categories project category)
        (ok true)))



;; Add these definitions
(define-map spending-limits principal uint)
(define-constant ERR-LIMIT-EXCEEDED (err u104))

(define-public (set-spending-limit (project principal) (limit uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set spending-limits project limit)
        (ok true)))



;; Add these definitions
(define-map budget-history
    {project: principal, timestamp: uint}
    {action: (string-ascii 20), amount: uint})
(define-data-var history-counter uint u0)

(define-public (log-budget-action (action (string-ascii 20)) (amount uint))
    (begin
        (map-set budget-history 
            {project: tx-sender, timestamp: block-height}
            {action: action, amount: amount})
        (var-set history-counter (+ (var-get history-counter) u1))
        (ok true)))



;; Add these definitions
(define-map project-milestones
    principal
    {target: uint, achieved: bool})

(define-public (set-milestone (project principal) (target uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set project-milestones project {target: target, achieved: false})
        (ok true)))



;; Add these definitions
(define-map budget-alerts
    principal
    {threshold: uint, triggered: bool})
(define-constant ALERT-THRESHOLD u80)

(define-public (set-budget-alert (threshold uint))
    (begin
        (map-set budget-alerts tx-sender 
            {threshold: threshold, triggered: false})
        (ok true)))



;; Add these definitions
(define-map performance-rewards
    principal
    {bonus: uint, claimed: bool})
(define-constant PERFORMANCE-THRESHOLD u90)

(define-public (claim-performance-reward)
    (let ((project-data (unwrap! (get-project-budget tx-sender) ERR-NOT-AUTHORIZED)))
        (asserts! (>= (get performance-score project-data) PERFORMANCE-THRESHOLD) ERR-NOT-AUTHORIZED)
        (map-set performance-rewards tx-sender {bonus: u100, claimed: true})
        (ok true)))



;; Add at the top with other data maps
(define-map vesting-schedules
    principal
    {total-amount: uint, 
     release-interval: uint,
     amount-per-release: uint,
     last-release: uint})

(define-public (create-vesting-schedule (project principal) (total uint) (interval uint) (amount-per uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set vesting-schedules project 
            {total-amount: total,
             release-interval: interval,
             amount-per-release: amount-per,
             last-release: block-height})
        (ok true)))


(define-map budget-votes 
    uint 
    {yes-votes: uint, no-votes: uint})

(define-data-var min-votes-required uint u3)

(define-public (vote-on-budget (proposal-id uint) (vote bool))
    (let ((current-votes (default-to {yes-votes: u0, no-votes: u0} 
                         (map-get? budget-votes proposal-id))))
        (map-set budget-votes proposal-id
            (if vote
                {yes-votes: (+ (get yes-votes current-votes) u1), 
                 no-votes: (get no-votes current-votes)}
                {yes-votes: (get yes-votes current-votes), 
                 no-votes: (+ (get no-votes current-votes) u1)}))
        (ok true)))




(define-map budget-delegates
    principal
    {delegate: principal, active: bool})

(define-public (delegate-budget-control (to principal))
    (begin
        (map-set budget-delegates tx-sender 
            {delegate: to, active: true})
        (ok true)))


(define-map project-tags
    principal
    (list 10 (string-ascii 20)))

(define-public (add-project-tags (tags (list 10 (string-ascii 20))))
    (begin
        (map-set project-tags tx-sender tags)
        (ok true)))


(define-map reporting-periods
    principal
    {start-block: uint,
     end-block: uint,
     target-spending: uint,
     actual-spending: uint})

(define-public (start-reporting-period (duration uint) (target uint))
    (begin
        (map-set reporting-periods tx-sender
            {start-block: block-height,
             end-block: (+ block-height duration),
             target-spending: target,
             actual-spending: u0})
        (ok true)))


(define-map multi-sig-requirements
    principal
    {required-signatures: uint,
     signers: (list 5 principal),
     signatures: uint})

(define-public (setup-multisig (project principal) (required uint) (signers (list 5 principal)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set multi-sig-requirements project
            {required-signatures: required,
             signers: signers,
             signatures: u0})
        (ok true)))



(define-constant RECLAIM-PERIOD u50)
(define-map unused-funds
    principal
    {last-activity: uint,
     reclaimable-amount: uint})

(define-public (mark-funds-reclaimable (project principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (let ((project-budget (unwrap! (get-project-budget project) ERR-NOT-AUTHORIZED)))
            (map-set unused-funds project
                {last-activity: block-height,
                 reclaimable-amount: (get balance project-budget)})
            (ok true))))


