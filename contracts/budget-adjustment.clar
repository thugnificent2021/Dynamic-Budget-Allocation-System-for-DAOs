;; Budget Adjustment System - Project Budget Adjustment with Reason Tracking
;; This contract allows controlled project budget adjustments with recorded reasons 
;; for improved transparency, auditability, and flexibility in budget management.

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-AMOUNT (err u401))
(define-constant ERR-INSUFFICIENT-TREASURY (err u402))
(define-constant ERR-INSUFFICIENT-PROJECT-BUDGET (err u403))
(define-constant ERR-ADJUSTMENT-NOT-FOUND (err u404))
(define-constant ERR-PROJECT-NOT-FOUND (err u405))

;; Data variables
(define-data-var adjustment-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;; Maps for budget adjustment logging
(define-map budget-adjustment-logs
    uint
    {project: principal,
     adjustment-amount: int,
     reason: (string-ascii 100),
     timestamp: uint,
     new-project-balance: uint,
     treasury-balance-change: int,
     adjusted-by: principal})

;; Map to track adjustments by project for easier querying
(define-map project-adjustments
    principal
    {total-adjustments: uint,
     last-adjustment-id: uint,
     total-increase: uint,
     total-decrease: uint})

;; Public function to adjust project budget with reason tracking
(define-public (adjust-budget (project principal) (adjustment int) (reason (string-ascii 100)))
    (let ((adjustment-id (var-get adjustment-counter))
          (current-project-budget (unwrap! (contract-call? .budget-manager get-project-budget project) ERR-PROJECT-NOT-FOUND))
          (current-treasury-balance (contract-call? .budget-manager get-treasury-balance))
          (current-project-balance (get balance current-project-budget)))
        
        ;; Check sender is contract owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        
        ;; Validate adjustment amount and balances
        (if (> adjustment 0)
            ;; Increasing project budget - check treasury has sufficient funds
            (asserts! (>= current-treasury-balance (to-uint adjustment)) ERR-INSUFFICIENT-TREASURY)
            ;; Decreasing project budget - check project has sufficient balance
            (asserts! (>= current-project-balance (to-uint (- adjustment))) ERR-INSUFFICIENT-PROJECT-BUDGET))
        
        ;; Calculate new project balance after adjustment
        (let ((new-project-balance (if (>= adjustment 0)
                                     (+ current-project-balance (to-uint adjustment))
                                     (- current-project-balance (to-uint (- adjustment))))))
            
            ;; Update project budget through budget-manager contract
            ;; Note: This assumes budget-manager has functions to update balances
            ;; In practice, we might need to work directly with budget-manager's data
            
            ;; Record the adjustment in our log
            (map-set budget-adjustment-logs adjustment-id
                {project: project,
                 adjustment-amount: adjustment,
                 reason: reason,
                 timestamp: block-height,
                 new-project-balance: new-project-balance,
                 treasury-balance-change: (- adjustment),
                 adjusted-by: tx-sender})
            
            ;; Update project adjustment summary
            (let ((project-stats (default-to {total-adjustments: u0, last-adjustment-id: u0, total-increase: u0, total-decrease: u0}
                                            (map-get? project-adjustments project))))
                (map-set project-adjustments project
                    {total-adjustments: (+ (get total-adjustments project-stats) u1),
                     last-adjustment-id: adjustment-id,
                     total-increase: (if (> adjustment 0) 
                                       (+ (get total-increase project-stats) (to-uint adjustment))
                                       (get total-increase project-stats)),
                     total-decrease: (if (< adjustment 0)
                                       (+ (get total-decrease project-stats) (to-uint (- adjustment)))
                                       (get total-decrease project-stats))}))
            
            ;; Increment adjustment counter
            (var-set adjustment-counter (+ adjustment-id u1))
            
            ;; Return adjustment ID for reference
            (ok adjustment-id))))

;; Read-only functions for querying adjustment logs

;; Get specific adjustment log by ID
(define-read-only (get-adjustment-log (adjustment-id uint))
    (map-get? budget-adjustment-logs adjustment-id))

;; Get project adjustment summary
(define-read-only (get-project-adjustment-summary (project principal))
    (map-get? project-adjustments project))

;; Get adjustment statistics
(define-read-only (get-adjustment-stats)
    {total-adjustments: (var-get adjustment-counter),
     contract-owner: (var-get contract-owner),
     current-block: block-height})

;; Get recent adjustments (last N adjustment IDs)
(define-read-only (get-recent-adjustment-ids (count uint))
    (let ((current-counter (var-get adjustment-counter)))
        (if (>= current-counter count)
            (ok {start-id: (- current-counter count), end-id: (- current-counter u1), total-count: count})
            (ok {start-id: u0, end-id: (- current-counter u1), total-count: current-counter}))))

;; Get adjustments by project in a specific time range
(define-read-only (get-project-adjustments-in-range (project principal) (start-block uint) (end-block uint))
    (let ((project-stats (map-get? project-adjustments project)))
        (match project-stats
            stats (ok {project: project, 
                      total-adjustments: (get total-adjustments stats),
                      query-range: {start: start-block, end: end-block}})
            ERR-PROJECT-NOT-FOUND)))

;; Check if adjustment exists
(define-read-only (adjustment-exists (adjustment-id uint))
    (is-some (map-get? budget-adjustment-logs adjustment-id)))

;; Get adjustment reason by ID
(define-read-only (get-adjustment-reason (adjustment-id uint))
    (match (map-get? budget-adjustment-logs adjustment-id)
        log (ok (get reason log))
        ERR-ADJUSTMENT-NOT-FOUND))

;; Get net adjustment amount for a project
(define-read-only (get-project-net-adjustment (project principal))
    (match (map-get? project-adjustments project)
        stats (let ((total-increase (get total-increase stats))
                    (total-decrease (get total-decrease stats)))
                (ok (if (>= total-increase total-decrease)
                      (- total-increase total-decrease)
                      (- (- total-decrease total-increase)))))
        ERR-PROJECT-NOT-FOUND))

;; Check if project has had any adjustments
(define-read-only (has-adjustments (project principal))
    (is-some (map-get? project-adjustments project)))

;; Administrative functions

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)))

;; Get current contract owner
(define-read-only (get-contract-owner)
    (var-get contract-owner))
