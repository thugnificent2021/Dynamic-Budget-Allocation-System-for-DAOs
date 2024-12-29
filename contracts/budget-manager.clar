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
