;; Sports Betting Smart Contract

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map bets 
  { bettor: principal, event-id: uint, prediction: (string-ascii 20) } 
  { amount: uint }
)
(define-map events 
  { id: uint } 
  { name: (string-ascii 100), options: (list 5 (string-ascii 20)), result: (optional (string-ascii 20)) }
)
(define-data-var next-event-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PREDICTION (err u102))
(define-constant ERR-EVENT-ALREADY-RESOLVED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))

;; Create a new event
(define-public (create-event (name (string-ascii 100)) (options (list 5 (string-ascii 20))))
  (let ((event-id (var-get next-event-id)))
    (if (is-eq tx-sender (var-get admin))
        (begin
          (map-set events { id: event-id } { name: name, options: options, result: none })
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
  )
    (asserts! (is-none (get result event)) ERR-EVENT-ALREADY-RESOLVED)
    (asserts! (is-some (index-of options prediction)) ERR-INVALID-PREDICTION)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set bets { bettor: tx-sender, event-id: event-id, prediction: prediction } { amount: amount })
    (ok true)
  )
)

;; Resolve an event
(define-public (resolve-event (event-id uint) (result (string-ascii 20)))
  (let ((event (unwrap! (map-get? events { id: event-id }) ERR-EVENT-NOT-FOUND)))
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
  )
    (map-delete bets { bettor: tx-sender, event-id: event-id, prediction: result })
    (as-contract (stx-transfer? amount tx-sender tx-sender))
  )
)

;; Read-only functions
(define-read-only (get-event (event-id uint))
  (map-get? events { id: event-id })
)

(define-read-only (get-bet (bettor principal) (event-id uint) (prediction (string-ascii 20)))
  (map-get? bets { bettor: bettor, event-id: event-id, prediction: prediction })
)