;; Updated smart contract for a simple sports betting system on Stacks blockchain using Clarity.

(define-data-var total-event-count uint 0) ;; Counter for total number of events
(define-data-var total-bet-count uint 0) ;; Counter for total number of bets

(define-map betting-events
  {
    event-id: uint
  }
  {
    event-title: (string-ascii 100), ;; Title of the sporting event
    possible-outcomes: (list 2 (string-ascii 20)), ;; Possible outcomes (e.g., ["Team A", "Team B"])
    event-resolved: bool, ;; Whether the event has been resolved
    winning-outcome: (optional (string-ascii 20)) ;; Winning outcome if resolved
  }
)

(define-map placed-bets
  {
    bet-id: uint
  }
  {
    associated-event-id: uint,
    bettor-address: principal, ;; Address of the person who placed the bet
    bet-amount: uint, ;; Amount of the bet
    chosen-outcome: (string-ascii 20), ;; Selected outcome by the bettor
    payout-claimed: bool ;; Whether the winnings have been claimed
  }
)

(define-event event-created (event-id uint event-title (string-ascii 100)))
(define-event bet-placed (bet-id uint event-id uint bettor principal amount uint outcome (string-ascii 20)))
(define-event event-resolved (event-id uint winning-outcome (string-ascii 20)))
(define-event winnings-claimed (bet-id uint amount uint))

;; Error codes for the contract
(define-constant ERR_INVALID_OUTCOME u100)
(define-constant ERR_EVENT_NOT_RESOLVED u101)
(define-constant ERR_NOT_A_WINNER u102)
(define-constant ERR_ALREADY_CLAIMED u103)
(define-constant ERR_UNAUTHORIZED u104)

;; Function to create a new betting event
(define-public (create-betting-event (title (string-ascii 100)) (outcomes (list 2 (string-ascii 20))))
  (let (
        (new-event-id (+ (var-get total-event-count) u1))
       )
    (begin
      ;; Ensure two unique outcomes are provided
      (asserts! (is-eq (len outcomes) u2) (err ERR_INVALID_OUTCOME))
      
      ;; Store the new event in the map
      (map-set betting-events
        {event-id: new-event-id}
        {event-title: title, possible-outcomes: outcomes, event-resolved: false, winning-outcome: none}
      )
      
      ;; Update the event counter
      (var-set total-event-count new-event-id)
      
      ;; Emit event
      (print (event-created new-event-id title))
      
      (ok new-event-id)
    )
  )
)

;; Function to place a bet on an event
(define-public (place-bet-on-event (event-id uint) (selected-outcome (string-ascii 20)))
  (let (
        (new-bet-id (+ (var-get total-bet-count) u1))
        (betting-event (map-get? betting-events {event-id: event-id}))
       )
    (match betting-event
      (some {possible-outcomes: possible-outcomes, event-resolved: event-resolved} 
        ;; Check if the selected outcome is valid
        (asserts! (is-eq (or (is-eq (get 0 possible-outcomes) selected-outcome)
                             (is-eq (get 1 possible-outcomes) selected-outcome)) true)
                  (err ERR_INVALID_OUTCOME))
        ;; Ensure the event is not resolved yet
        (asserts! (is-eq event-resolved false) (err ERR_EVENT_NOT_RESOLVED))
        
        ;; Save the bet information
        (map-set placed-bets
          {bet-id: new-bet-id}
          {associated-event-id: event-id, bettor-address: tx-sender, bet-amount: (stx-get-balance tx-sender), 
           chosen-outcome: selected-outcome, payout-claimed: false}
        )
        
        ;; Update the bet counter
        (var-set total-bet-count new-bet-id)
        
        ;; Emit event
        (print (bet-placed new-bet-id event-id tx-sender (stx-get-balance tx-sender) selected-outcome))
        
        (ok new-bet-id)
      )
      (none (err ERR_INVALID_OUTCOME))
    )
  )
)

;; Function to resolve a betting event and declare a winning outcome
(define-public (resolve-betting-event (event-id uint) (winning-outcome (string-ascii 20)))
  (let (
        (betting-event (map-get? betting-events {event-id: event-id}))
       )
    (match betting-event
      (some {possible-outcomes: possible-outcomes, event-resolved: event-resolved}
        ;; Ensure only the contract owner can resolve
        (asserts! (is-eq (tx-sender) (contract-owner?)) (err ERR_UNAUTHORIZED))
        ;; Check if the selected winning outcome is valid
        (asserts! (is-eq (or (is-eq (get 0 possible-outcomes) winning-outcome)
                             (is-eq (get 1 possible-outcomes) winning-outcome)) true)
                  (err ERR_INVALID_OUTCOME))
        ;; Ensure the event is not already resolved
        (asserts! (is-eq event-resolved false) (err ERR_EVENT_NOT_RESOLVED))
        
        ;; Update the event with the winning outcome
        (map-set betting-events
          {event-id: event-id}
          {event-title: (get event-title (unwrap-panic (map-get betting-events {event-id: event-id}))),
           possible-outcomes: possible-outcomes, event-resolved: true, winning-outcome: (some winning-outcome)}
        )
        
        ;; Emit event
        (print (event-resolved event-id winning-outcome))
        
        (ok event-id)
      )
      (none (err ERR_INVALID_OUTCOME))
    )
  )
)

;; Function to claim winnings from a resolved bet
(define-public (claim-bet-winnings (bet-id uint))
  (let (
        (bet-details (map-get? placed-bets {bet-id: bet-id}))
       )
    (match bet-details
      (some {associated-event-id: event-id, bettor-address: bettor, bet-amount: bet-amount, chosen-outcome: chosen-outcome, payout-claimed: payout-claimed}
        (let (
              (betting-event (map-get? betting-events {event-id: event-id}))
             )
          (match betting-event
            (some {event-resolved: event-resolved, winning-outcome: winning-outcome}
              ;; Ensure the event is resolved
              (asserts! event-resolved (err ERR_EVENT_NOT_RESOLVED))
              ;; Check if the user is the winner
              (asserts! (is-eq winning-outcome (some chosen-outcome)) (err ERR_NOT_A_WINNER))
              ;; Ensure the winnings have not been claimed
              (asserts! (is-eq payout-claimed false) (err ERR_ALREADY_CLAIMED))
              
              ;; Transfer winnings
              (stx-transfer? (* bet-amount u2) tx-sender bettor)
              
              ;; Mark the bet as claimed
              (map-set placed-bets
                {bet-id: bet-id}
                {associated-event-id: event-id, bettor-address: bettor, bet-amount: bet-amount, 
                 chosen-outcome: chosen-outcome, payout-claimed: true}
              )
              
              ;; Emit event
              (print (winnings-claimed bet-id (* bet-amount u2)))
              
              (ok (* bet-amount u2))
            )
            (none (err ERR_INVALID_OUTCOME))
          )
        )
      )
      (none (err ERR_INVALID_OUTCOME))
    )
  )
)
