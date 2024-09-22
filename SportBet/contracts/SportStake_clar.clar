;; Sports Betting Smart Contract

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map bets 
  { bettor: principal, event-id: uint, prediction: (string-ascii 20) } 
  { amount: uint }
)
(define-map events 
  { id: uint } 
  { 
    name: (string-ascii 100), 
    options: (list 5 (string-ascii 20)), 
    odds: (list 5 uint),
    start-block: uint,
    end-block: uint,
    result: (optional (string-ascii 20)) 
  }
)
(define-data-var next-event-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PREDICTION (err u102))
(define-constant ERR-EVENT-ALREADY-RESOLVED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-START-TIME (err u105))
(define-constant ERR-INVALID-END-TIME (err u106))
(define-constant ERR-BETTING-CLOSED (err u107))
(define-constant ERR-EVENT-NOT-ENDED (err u108))

;; Create a new event
(define-public (create-event (name (string-ascii 100)) (options (list 5 (string-ascii 20))) (odds (list 5 uint)) (start-block uint) (end-block uint))
  (let ((event-id (var-get next-event-id)))
    (if (is-eq tx-sender (var-get admin))
        (begin
          (asserts! (> start-block block-height) ERR-INVALID-START-TIME)
          (asserts! (> end-block start-block) ERR-INVALID-END-TIME)
          (map-set events { id: event-id } 
            { name: name, options: options, odds: odds, start-block: start-block, end-block: end-block, result: none })
          (var-set next-event-id (+ event-id u1))
          (ok event-id)
        )
        ERR-NOT-AUTHORIZED
    )
  )
)

;; Place a bet
(define-public (place-bet (event-id uint) (prediction (string-ascii 20)) (amount uint))
  (let (
    (event (unwrap! (map-get? events { id: event-id }) ERR-EVENT-NOT-FOUND))
    (options (get options event))
    (start-block (get start-block event))
    (end-block (get end-block event))
  )
    (asserts! (is-none (get result event)) ERR-EVENT-ALREADY-RESOLVED)
    (asserts! (is-some (index-of options prediction)) ERR-INVALID-PREDICTION)
    (asserts! (and (>= block-height start-block) (< block-height end-block)) ERR-BETTING-CLOSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set bets { bettor: tx-sender, event-id: event-id, prediction: prediction } { amount: amount })
    (ok true)
  )
)

;; Resolve an event
(define-public (resolve-event (event-id uint) (result (string-ascii 20)))
  (let (
    (event (unwrap! (map-get? events { id: event-id }) ERR-EVENT-NOT-FOUND))
    (end-block (get end-block event))
  )
    (asserts! (>= block-height end-block) ERR-EVENT-NOT-ENDED)
    (if (is-eq tx-sender (var-get admin))
        (begin
          (map-set events { id: event-id } 
            (merge event { result: (some result) }))
          (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
  )
)

;; Claim winnings
(define-public (claim-winnings (event-id uint))
  (let (
    (event (unwrap! (map-get? events { id: event-id }) ERR-EVENT-NOT-FOUND))
    (result (unwrap! (get result event) ERR-EVENT-ALREADY-RESOLVED))
    (bet (unwrap! (map-get? bets { bettor: tx-sender, event-id: event-id, prediction: result }) ERR-INSUFFICIENT-BALANCE))
    (amount (get amount bet))
    (odds-list (get odds event))
    (index (unwrap! (index-of (get options event) result) ERR-INVALID-PREDICTION))
    (odds (unwrap! (element-at odds-list index) ERR-INVALID-PREDICTION))
    (payout (/ (* amount odds) u100))  ;; Assuming odds are represented as percentages
  )
    (map-delete bets { bettor: tx-sender, event-id: event-id, prediction: result })
    (as-contract (stx-transfer? payout tx-sender tx-sender))
  )
)

;; Read-only functions
(define-read-only (get-event (event-id uint))
  (map-get? events { id: event-id })
)

(define-read-only (get-bet (bettor principal) (event-id uint) (prediction (string-ascii 20)))
  (map-get? bets { bettor: bettor, event-id: event-id, prediction: prediction })
)

;; Helper function to check if betting is open for an event
(define-read-only (is-betting-open (event-id uint))
  (let (
    (event (unwrap! (map-get? events { id: event-id }) false))
    (start-block (get start-block event))
    (end-block (get end-block event))
  )
    (and (>= block-height start-block) (< block-height end-block))
  )
)