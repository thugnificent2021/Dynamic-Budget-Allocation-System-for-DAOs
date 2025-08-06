;; Budget Governance System - Democratic budget oversight and policy management

;; Error constants  
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u301))
(define-constant ERR-VOTING-CLOSED (err u302))
(define-constant ERR-PROPOSAL-ACTIVE (err u303))
(define-constant ERR-INSUFFICIENT-STAKE (err u304))
(define-constant ERR-DUPLICATE-VOTE (err u305))
(define-constant ERR-INVALID-THRESHOLD (err u306))
(define-constant ERR-PROPOSAL-EXECUTED (err u307))
(define-constant ERR-QUORUM-NOT-MET (err u308))
(define-constant ERR-INVALID-PROPOSAL-TYPE (err u309))
(define-constant ERR-DELEGATION-EXISTS (err u310))

;; Governance parameters
(define-constant MIN-PROPOSAL-STAKE u1000)
(define-constant VOTING-PERIOD u100)
(define-constant EXECUTION-DELAY u50)
(define-constant QUORUM-THRESHOLD u30)
(define-constant APPROVAL-THRESHOLD u60)
(define-constant MAX-PROPOSALS-PER-USER u5)

;; Data variables
(define-data-var proposal-counter uint u0)
(define-data-var governance-token-supply uint u100000)
(define-data-var total-delegated-votes uint u0)
(define-data-var contract-owner principal tx-sender)

;; Governance token balances and voting power
(define-map governance-tokens
    principal
    {balance: uint,
     delegated-to: (optional principal),
     last-activity: uint,
     reputation-score: uint})

;; Voting power delegation system
(define-map vote-delegations
    principal
    {delegate: principal,
     voting-power: uint,
     expires-at: uint,
     active: bool})

;; Consolidated voting power tracking
(define-map voting-power
    principal
    {direct-power: uint,
     delegated-power: uint,
     total-power: uint,
     last-updated: uint})

;; Governance proposals with comprehensive tracking
(define-map governance-proposals
    uint
    {proposer: principal,
     proposal-type: (string-ascii 30),
     title: (string-ascii 100),
     description: (string-ascii 500),
     target-contract: (string-ascii 50),
     function-call: (string-ascii 100),
     parameters: (string-ascii 200),
     stake-amount: uint,
     submission-time: uint,
     voting-start: uint,
     voting-end: uint,
     execution-time: uint,
     yes-votes: uint,
     no-votes: uint,
     abstain-votes: uint,
     total-voters: uint,
     quorum-met: bool,
     approved: bool,
     executed: bool,
     canceled: bool})

;; Individual vote tracking with detailed information
(define-map proposal-votes
    {proposal-id: uint, voter: principal}
    {vote: (string-ascii 10),
     voting-power: uint,
     timestamp: uint,
     reason: (string-ascii 200)})

;; Governance committee system for elevated proposals
(define-map committee-members
    principal
    {role: (string-ascii 20),
     appointed-by: principal,
     appointment-date: uint,
     term-expires: uint,
     active: bool})

;; Policy change tracking and version control
(define-map governance-policies
    (string-ascii 50)
    {current-value: uint,
     proposed-value: uint,
     last-changed: uint,
     change-count: uint,
     requires-committee: bool})

;; Proposal execution queue with priority system
(define-map execution-queue
    uint
    {proposal-id: uint,
     execution-block: uint,
     priority-level: uint,
     dependencies: (list 5 uint),
     ready-for-execution: bool})

;; User proposal tracking to prevent spam
(define-map user-proposal-count
    principal
    {active-proposals: uint,
     total-proposals: uint,
     last-proposal-time: uint,
     reputation-penalty: uint})

;; Initialize governance token distribution
(define-public (distribute-governance-tokens (holder principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INSUFFICIENT-STAKE)
        
        (map-set governance-tokens holder
            {balance: amount,
             delegated-to: none,
             last-activity: block-height,
             reputation-score: u100})
        
        (map-set voting-power holder
            {direct-power: amount,
             delegated-power: u0,
             total-power: amount,
             last-updated: block-height})
        
        (ok true)))

;; Delegate voting power with time limits and conditions
(define-public (delegate-voting-power (delegate principal) (duration uint))
    (let ((current-tokens (default-to {balance: u0, delegated-to: none, last-activity: u0, reputation-score: u50}
                                     (map-get? governance-tokens tx-sender)))
          (current-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                     (map-get? voting-power tx-sender))))
        
        (asserts! (> (get balance current-tokens) u0) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (get delegated-to current-tokens)) ERR-DELEGATION-EXISTS)
        (asserts! (not (is-eq delegate tx-sender)) ERR-NOT-AUTHORIZED)
        
        ;; Create delegation record
        (map-set vote-delegations tx-sender
            {delegate: delegate,
             voting-power: (get balance current-tokens),
             expires-at: (+ block-height duration),
             active: true})
        
        ;; Update token delegation status
        (map-set governance-tokens tx-sender
            (merge current-tokens {delegated-to: (some delegate)}))
        
        ;; Update voting power for delegator
        (map-set voting-power tx-sender
            (merge current-power {direct-power: u0, total-power: u0}))
        
        ;; Update voting power for delegate
        (let ((delegate-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                         (map-get? voting-power delegate))))
            (map-set voting-power delegate
                {direct-power: (get direct-power delegate-power),
                 delegated-power: (+ (get delegated-power delegate-power) (get balance current-tokens)),
                 total-power: (+ (get total-power delegate-power) (get balance current-tokens)),
                 last-updated: block-height}))
        
        (var-set total-delegated-votes (+ (var-get total-delegated-votes) (get balance current-tokens)))
        (ok true)))

;; Submit governance proposal with comprehensive validation
(define-public (submit-proposal 
                (proposal-type (string-ascii 30))
                (title (string-ascii 100))
                (description (string-ascii 500))
                (target-contract (string-ascii 50))
                (function-call (string-ascii 100))
                (parameters (string-ascii 200))
                (stake-amount uint))
    (let ((proposal-id (var-get proposal-counter))
          (user-stats (default-to {active-proposals: u0, total-proposals: u0, last-proposal-time: u0, reputation-penalty: u0}
                                 (map-get? user-proposal-count tx-sender)))
          (voter-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                  (map-get? voting-power tx-sender))))
        
        (asserts! (>= stake-amount MIN-PROPOSAL-STAKE) ERR-INSUFFICIENT-STAKE)
        (asserts! (<= (get active-proposals user-stats) MAX-PROPOSALS-PER-USER) ERR-NOT-AUTHORIZED)
        (asserts! (> (get total-power voter-power) u0) ERR-INSUFFICIENT-STAKE)
        
        ;; Create comprehensive proposal record
        (map-set governance-proposals proposal-id
            {proposer: tx-sender,
             proposal-type: proposal-type,
             title: title,
             description: description,
             target-contract: target-contract,
             function-call: function-call,
             parameters: parameters,
             stake-amount: stake-amount,
             submission-time: block-height,
             voting-start: (+ block-height u10),
             voting-end: (+ block-height VOTING-PERIOD),
             execution-time: (+ block-height VOTING-PERIOD EXECUTION-DELAY),
             yes-votes: u0,
             no-votes: u0,
             abstain-votes: u0,
             total-voters: u0,
             quorum-met: false,
             approved: false,
             executed: false,
             canceled: false})
        
        ;; Update user proposal tracking
        (map-set user-proposal-count tx-sender
            {active-proposals: (+ (get active-proposals user-stats) u1),
             total-proposals: (+ (get total-proposals user-stats) u1),
             last-proposal-time: block-height,
             reputation-penalty: (get reputation-penalty user-stats)})
        
        ;; Add to execution queue
        (map-set execution-queue proposal-id
            {proposal-id: proposal-id,
             execution-block: (+ block-height VOTING-PERIOD EXECUTION-DELAY),
             priority-level: u1,
             dependencies: (list),
             ready-for-execution: false})
        
        (var-set proposal-counter (+ proposal-id u1))
        (ok proposal-id)))

;; Vote on proposal with detailed tracking and validation
(define-public (vote-on-proposal (proposal-id uint) (vote (string-ascii 10)) (reason (string-ascii 200)))
    (let ((proposal-data (unwrap! (map-get? governance-proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
          (voter-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                  (map-get? voting-power tx-sender))))
        
        (asserts! (>= block-height (get voting-start proposal-data)) ERR-VOTING-CLOSED)
        (asserts! (<= block-height (get voting-end proposal-data)) ERR-VOTING-CLOSED)
        (asserts! (> (get total-power voter-power) u0) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (map-get? proposal-votes {proposal-id: proposal-id, voter: tx-sender})) ERR-DUPLICATE-VOTE)
        (asserts! (not (get executed proposal-data)) ERR-PROPOSAL-EXECUTED)
        
        ;; Record individual vote
        (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender}
            {vote: vote,
             voting-power: (get total-power voter-power),
             timestamp: block-height,
             reason: reason})
        
        ;; Update proposal vote counts
        (let ((updated-proposal 
               (if (is-eq vote "yes")
                   (merge proposal-data 
                          {yes-votes: (+ (get yes-votes proposal-data) (get total-power voter-power)),
                           total-voters: (+ (get total-voters proposal-data) u1)})
                   (if (is-eq vote "no")
                       (merge proposal-data 
                              {no-votes: (+ (get no-votes proposal-data) (get total-power voter-power)),
                               total-voters: (+ (get total-voters proposal-data) u1)})
                       (merge proposal-data 
                              {abstain-votes: (+ (get abstain-votes proposal-data) (get total-power voter-power)),
                               total-voters: (+ (get total-voters proposal-data) u1)})))))
            
            ;; Check if quorum is met
            (let ((total-votes (+ (+ (get yes-votes updated-proposal) (get no-votes updated-proposal)) (get abstain-votes updated-proposal)))
                  (quorum-requirement (/ (* (var-get governance-token-supply) QUORUM-THRESHOLD) u100)))
                
                (map-set governance-proposals proposal-id
                    (merge updated-proposal 
                           {quorum-met: (>= total-votes quorum-requirement)}))))
        
        (ok true)))

;; Execute approved proposal with comprehensive checks
(define-public (execute-proposal (proposal-id uint))
    (let ((proposal-data (unwrap! (map-get? governance-proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
          (queue-data (unwrap! (map-get? execution-queue proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        
        (asserts! (> block-height (get voting-end proposal-data)) ERR-VOTING-CLOSED)
        (asserts! (>= block-height (get execution-time proposal-data)) ERR-VOTING-CLOSED)
        (asserts! (not (get executed proposal-data)) ERR-PROPOSAL-EXECUTED)
        (asserts! (get quorum-met proposal-data) ERR-QUORUM-NOT-MET)
        
        ;; Check approval threshold
        (let ((total-decisive-votes (+ (get yes-votes proposal-data) (get no-votes proposal-data)))
              (approval-required (/ (* total-decisive-votes APPROVAL-THRESHOLD) u100)))
            
            (asserts! (>= (get yes-votes proposal-data) approval-required) ERR-NOT-AUTHORIZED)
            
            ;; Mark proposal as executed
            (map-set governance-proposals proposal-id
                (merge proposal-data {executed: true, approved: true}))
            
            ;; Update execution queue
            (map-set execution-queue proposal-id
                (merge queue-data {ready-for-execution: true}))
            
            ;; Update proposer reputation
            (let ((proposer-tokens (default-to {balance: u0, delegated-to: none, last-activity: u0, reputation-score: u50}
                                              (map-get? governance-tokens (get proposer proposal-data)))))
                (map-set governance-tokens (get proposer proposal-data)
                    (merge proposer-tokens 
                           {reputation-score: (if (< (get reputation-score proposer-tokens) u95)
                                                 (+ (get reputation-score proposer-tokens) u5)
                                                 u100)})))
            
            (ok true))))

;; Committee member management for elevated governance
(define-public (appoint-committee-member (member principal) (role (string-ascii 20)) (term-length uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        
        (map-set committee-members member
            {role: role,
             appointed-by: tx-sender,
             appointment-date: block-height,
             term-expires: (+ block-height term-length),
             active: true})
        
        (ok true)))

;; Policy change management with version control
(define-public (update-governance-policy (policy-name (string-ascii 50)) (new-value uint) (requires-committee bool))
    (let ((current-policy (default-to {current-value: u0, proposed-value: u0, last-changed: u0, change-count: u0, requires-committee: false}
                                     (map-get? governance-policies policy-name))))
        
        (if (get requires-committee current-policy)
            (asserts! (is-some (map-get? committee-members tx-sender)) ERR-NOT-AUTHORIZED)
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
        
        (map-set governance-policies policy-name
            {current-value: new-value,
             proposed-value: u0,
             last-changed: block-height,
             change-count: (+ (get change-count current-policy) u1),
             requires-committee: requires-committee})
        
        (ok true)))

;; Revoke delegation and reclaim voting power
(define-public (revoke-delegation)
    (let ((delegation-data (unwrap! (map-get? vote-delegations tx-sender) ERR-NOT-AUTHORIZED))
          (current-tokens (unwrap! (map-get? governance-tokens tx-sender) ERR-NOT-AUTHORIZED)))
        
        (asserts! (get active delegation-data) ERR-NOT-AUTHORIZED)
        
        ;; Deactivate delegation
        (map-set vote-delegations tx-sender
            (merge delegation-data {active: false}))
        
        ;; Restore direct voting power
        (map-set governance-tokens tx-sender
            (merge current-tokens {delegated-to: none}))
        
        ;; Update voting power records
        (let ((current-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                        (map-get? voting-power tx-sender))))
            (map-set voting-power tx-sender
                {direct-power: (get balance current-tokens),
                 delegated-power: (get delegated-power current-power),
                 total-power: (get balance current-tokens),
                 last-updated: block-height}))
        
        ;; Update delegate's voting power
        (let ((delegate (get delegate delegation-data))
              (delegate-power (default-to {direct-power: u0, delegated-power: u0, total-power: u0, last-updated: u0}
                                         (map-get? voting-power delegate))))
            (map-set voting-power delegate
                {direct-power: (get direct-power delegate-power),
                 delegated-power: (- (get delegated-power delegate-power) (get voting-power delegation-data)),
                 total-power: (- (get total-power delegate-power) (get voting-power delegation-data)),
                 last-updated: block-height}))
        
        (var-set total-delegated-votes (- (var-get total-delegated-votes) (get voting-power delegation-data)))
        (ok true)))

;; Read-only functions for querying governance state
(define-read-only (get-proposal-details (proposal-id uint))
    (map-get? governance-proposals proposal-id))

(define-read-only (get-voting-power (user principal))
    (map-get? voting-power user))

(define-read-only (get-governance-tokens (user principal))
    (map-get? governance-tokens user))

(define-read-only (get-vote-details (proposal-id uint) (voter principal))
    (map-get? proposal-votes {proposal-id: proposal-id, voter: voter}))

(define-read-only (get-committee-member (member principal))
    (map-get? committee-members member))

(define-read-only (get-governance-policy (policy-name (string-ascii 50)))
    (map-get? governance-policies policy-name))

(define-read-only (get-delegation-info (user principal))
    (map-get? vote-delegations user))

(define-read-only (get-user-proposal-stats (user principal))
    (map-get? user-proposal-count user))

(define-read-only (get-execution-queue-item (proposal-id uint))
    (map-get? execution-queue proposal-id))

(define-read-only (get-governance-stats)
    {total-proposals: (var-get proposal-counter),
     total-token-supply: (var-get governance-token-supply),
     total-delegated-votes: (var-get total-delegated-votes),
     current-block: block-height})




