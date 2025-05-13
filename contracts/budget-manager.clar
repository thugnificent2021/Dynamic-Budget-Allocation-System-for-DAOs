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


(define-constant REALLOCATION-THRESHOLD u50)

(define-public (reallocate-low-performing-budgets)
    (let ((project-budget (unwrap! (get-project-budget tx-sender) ERR-NOT-AUTHORIZED)))
        (asserts! (< (get performance-score project-budget) REALLOCATION-THRESHOLD) ERR-NOT-AUTHORIZED)
        (var-set treasury-balance (+ (var-get treasury-balance) (get balance project-budget)))
        (map-set budgets tx-sender 
            {balance: u0, performance-score: (get performance-score project-budget)})
        (ok true)))



(define-map budget-increase-requests 
    principal 
    {amount: uint, reason: (string-ascii 50), status: bool})

(define-public (request-budget-increase (amount uint) (reason (string-ascii 50)))
    (begin
        (map-set budget-increase-requests tx-sender 
            {amount: amount, reason: reason, status: false})
        (ok true)))



(define-map budget-analytics
    principal
    {total-spent: uint, last-active: uint, transaction-count: uint})

(define-public (record-budget-usage (amount uint))
    (let ((current-analytics (default-to {total-spent: u0, last-active: u0, transaction-count: u0} 
                            (map-get? budget-analytics tx-sender))))
        (map-set budget-analytics tx-sender
            {total-spent: (+ (get total-spent current-analytics) amount),
             last-active: block-height,
             transaction-count: (+ (get transaction-count current-analytics) u1)})
        (ok true)))




(define-map frozen-budgets principal bool)

(define-public (freeze-budget (project principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set frozen-budgets project true)
        (ok true)))

(define-public (unfreeze-budget (project principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set frozen-budgets project false)
        (ok true)))



(define-public (merge-budgets (from-project principal) (to-project principal))
    (let ((from-budget (unwrap! (get-project-budget from-project) ERR-NOT-AUTHORIZED))
          (to-budget (unwrap! (get-project-budget to-project) ERR-NOT-AUTHORIZED)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set budgets to-project 
            {balance: (+ (get balance from-budget) (get balance to-budget)),
             performance-score: (get performance-score to-budget)})
        (map-set budgets from-project 
            {balance: u0, performance-score: u0})
        (ok true)))



(define-map budget-priorities 
    principal 
    {level: uint, last-updated: uint})

(define-public (set-budget-priority (project principal) (priority-level uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set budget-priorities project 
            {level: priority-level, last-updated: block-height})
        (ok true)))



(define-constant DISTRIBUTION-CYCLE u100)
(define-map distribution-schedule
    principal
    {amount: uint, cycle: uint, last-distribution: uint})

(define-public (setup-auto-distribution (amount uint) (cycle uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set distribution-schedule tx-sender
            {amount: amount, cycle: cycle, last-distribution: block-height})
        (ok true)))



(define-map budget-rollovers
    principal
    {amount: uint, expiry: uint})

(define-public (rollover-unused-budget (amount uint) (duration uint))
    (let ((current-budget (unwrap! (get-project-budget tx-sender) ERR-NOT-AUTHORIZED)))
        (asserts! (<= amount (get balance current-budget)) ERR-INSUFFICIENT-BALANCE)
        (map-set budget-rollovers tx-sender
            {amount: amount, expiry: (+ block-height duration)})
        (map-set budgets tx-sender 
            {balance: (- (get balance current-budget) amount),
             performance-score: (get performance-score current-budget)})
        (ok true)))



(define-map budget-approval-workflow
    principal
    {status: (string-ascii 20), 
     approver: principal, 
     requested-amount: uint, 
     approved-amount: uint})

(define-public (request-budget-approval (amount uint))
    (begin
        (map-set budget-approval-workflow tx-sender
            {status: "pending", 
             approver: (var-get contract-owner), 
             requested-amount: amount, 
             approved-amount: u0})
        (ok true)))

(define-public (approve-budget-request (project principal) (approved-amount uint))
    (let ((request (unwrap! (map-get? budget-approval-workflow project) ERR-NOT-AUTHORIZED)))
        (asserts! (is-eq tx-sender (get approver request)) ERR-NOT-AUTHORIZED)
        (map-set budget-approval-workflow project
            {status: "approved", 
             approver: (get approver request), 
             requested-amount: (get requested-amount request), 
             approved-amount: approved-amount})
        (ok true)))



(define-map budget-forecasts
    principal
    {current-quarter: uint, 
     next-quarter: uint, 
     forecast-date: uint})

(define-public (set-budget-forecast (current uint) (next uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set budget-forecasts tx-sender
            {current-quarter: current, 
             next-quarter: next, 
             forecast-date: block-height})
        (ok true)))

(define-read-only (get-budget-forecast (project principal))
    (map-get? budget-forecasts project))



(define-map transfer-limits
    principal
    {daily-limit: uint, 
     transaction-limit: uint, 
     last-reset: uint, 
     used-today: uint})

(define-constant ERR-TRANSFER-LIMIT-EXCEEDED (err u105))
(define-constant BLOCKS-PER-DAY u144)

(define-public (set-transfer-limits (daily uint) (per-tx uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set transfer-limits tx-sender
            {daily-limit: daily, 
             transaction-limit: per-tx, 
             last-reset: block-height, 
             used-today: u0})
        (ok true)))

(define-public (check-and-update-transfer-limit (amount uint))
    (let ((limits (default-to {daily-limit: u0, transaction-limit: u0, last-reset: u0, used-today: u0} 
                             (map-get? transfer-limits tx-sender))))
        (asserts! (<= amount (get transaction-limit limits)) ERR-TRANSFER-LIMIT-EXCEEDED)
        (if (> (- block-height (get last-reset limits)) BLOCKS-PER-DAY)
            (map-set transfer-limits tx-sender
                {daily-limit: (get daily-limit limits), 
                 transaction-limit: (get transaction-limit limits), 
                 last-reset: block-height, 
                 used-today: amount})
            (begin
                (asserts! (<= (+ amount (get used-today limits)) (get daily-limit limits)) 
                          ERR-TRANSFER-LIMIT-EXCEEDED)
                (map-set transfer-limits tx-sender
                    {daily-limit: (get daily-limit limits), 
                     transaction-limit: (get transaction-limit limits), 
                     last-reset: (get last-reset limits), 
                     used-today: (+ amount (get used-today limits))})))
        (ok true)))






(define-map time-locked-delegates
    principal
    {delegate: principal,
     expires-at: uint,
     permissions: (list 3 (string-ascii 10))})

(define-constant ERR-EXPIRED-DELEGATION (err u106))
(define-constant ERR-INVALID-DELEGATE (err u107))

(define-public (create-time-locked-delegation (delegate principal) (duration uint) (permissions (list 3 (string-ascii 10))))
    (begin
        (asserts! (not (is-eq delegate tx-sender)) ERR-INVALID-DELEGATE)
        (map-set time-locked-delegates tx-sender
            {delegate: delegate,
             expires-at: (+ block-height duration),
             permissions: permissions})
        (ok true)))

(define-read-only (get-active-delegation (owner principal))
    (let ((delegation-data (map-get? time-locked-delegates owner)))
        (match delegation-data
            d
            (if (> (get expires-at d) block-height)
                (ok d)
                ERR-EXPIRED-DELEGATION)
            ERR-NOT-AUTHORIZED)))


(define-map scaling-parameters
    principal
    {base-budget: uint,
     min-budget: uint,
     max-budget: uint,
     scale-factor: uint})

(define-constant SCALE-DENOMINATOR u100)
(define-constant ERR-INVALID-PARAMETERS (err u108))

(define-public (set-scaling-parameters (base uint) (min uint) (max uint) (factor uint))
    (begin
        (asserts! (and (>= max base) (>= base min) (<= factor SCALE-DENOMINATOR)) ERR-INVALID-PARAMETERS)
        (map-set scaling-parameters tx-sender
            {base-budget: base,
             min-budget: min,
             max-budget: max,
             scale-factor: factor})
        (ok true)))

(define-public (auto-scale-budget (project principal))
    (let ((params (unwrap! (map-get? scaling-parameters project) ERR-NOT-AUTHORIZED))
          (current-budget (unwrap! (get-project-budget project) ERR-NOT-AUTHORIZED))
          (performance-multiplier (/ (* (get performance-score current-budget) (get scale-factor params)) SCALE-DENOMINATOR))
          (new-budget (if (>= (* (get base-budget params) performance-multiplier) (get max-budget params))
                         (get max-budget params)
                         (if (<= (* (get base-budget params) performance-multiplier) (get min-budget params))
                             (get min-budget params)
                             (* (get base-budget params) performance-multiplier)))))
        (map-set budgets project
            {balance: new-budget,
             performance-score: (get performance-score current-budget)})
        (ok true)))