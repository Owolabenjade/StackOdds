;; Updated smart contract for sports betting with support for multiple bet types and complex bets

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
    winning-outcome: (optional (string-ascii 20)), ;; Winning outcome if resolved
    point-spread: (optional int), ;; Point spread for the event (if applicable)
    over-under: (optional uint) ;; Over/Under value for the event (if applicable)
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
    bet-type: (string-ascii 20), ;; Type of the bet (e.g., "single", "parlay", "over/under", "point-spread")
    bet-details: (optional (string-ascii 50)), ;; Additional details for complex bets (e.g., combined event IDs)
    payout-claimed: bool ;; Whether the winnings have been claimed
  }
)

(define-event event-created (event-id uint event-title (string-ascii 100)))
(define-event bet-placed (bet-id uint event-id uint bettor principal amount uint outcome (string-ascii 20) bet-type (string-ascii 20)))
(define-event event-resolved (event-id uint winning-outcome (string-ascii 20)))
(define-event winnings-claimed (bet-id uint amount uint))

;; Error codes for the contract
(define-constant ERR_INVALID_OUTCOME u100)
(define-constant ERR_EVENT_NOT_RESOLVED u101)
(define-constant ERR_NOT_A_WINNER u102)
(define-constant ERR_ALREADY_CLAIMED u103)
(define-constant ERR_UNAUTHORIZED u104)
(define-constant ERR_INVALID_BET_TYPE u105)
(define-constant ERR_INVALID_BET_DETAILS u106)

;; Function to create a new betting event with optional point spread and over/under
(define-public (create-betting-event (title (string-ascii 100)) (outcomes (list 2 (string-ascii 20))) (spread (optional int)) (over-under (optional uint)))
  (let (
        (new-event-id (+ (var-get total-event-count) u1))
       )
    (begin
      ;; Ensure two unique outcomes are provided
      (asserts! (is-eq (len outcomes) u2) (err ERR_INVALID_OUTCOME))
      
      ;; Store the new event in the map
      (map-set betting-events
        {event-id: new-event-id}
        {event-title: title, possible-outcomes: outcomes, event-resolved: false, winning-outcome: none, point-spread: spread, over-under: over-under}
      )
      
      ;; Update the event counter
      (var-set total-event-count new-event-id)
      
      ;; Emit event
      (print (event-created new-event-id title))
      
      (ok new-event-id)
    )
  )
)

;; Function to place a bet on an event with different bet types
(define-public (place-bet-on-event (event-id uint) (selected-outcome (string-ascii 20)) (bet-type (string-ascii 20)) (bet-details (optional (string-ascii 50))))
  (let (
        (new-bet-id (+ (var-get total-bet-count) u1))
        (betting-event (map-get? betting-events {event-id: event-id}))
       )
    (match betting-event
      (some {possible-outcomes: possible-outcomes, event-resolved: event-resolved, point-spread: spread, over-under: over-under} 
        ;; Check if the selected outcome is valid
        (asserts! (is-eq (or (is-eq (get 0 possible-outcomes) selected-outcome)
                             (is-eq (get 1 possible-outcomes) selected-outcome)) true)
                  (err ERR_INVALID_OUTCOME))
        ;; Ensure the event is not resolved yet
        (asserts! (is-eq event-resolved false) (err ERR_EVENT_NOT_RESOLVED))

        ;; Validate bet type and details
        (asserts! (is-valid-bet-type bet-type spread over-under bet-details) (err ERR_INVALID_BET_TYPE))
        
        ;; Save the bet information
        (map-set placed-bets
          {bet-id: new-bet-id}
          {associated-event-id: event-id, bettor-address: tx-sender, bet-amount: (stx-get-balance tx-sender), 
           chosen-outcome: selected-outcome, bet-type: bet-type, bet-details: bet-details, payout-claimed: false}
        )
        
        ;; Update the bet counter
        (var-set total-bet-count new-bet-id)
        
        ;; Emit event
        (print (bet-placed new-bet-id event-id tx-sender (stx-get-balance tx-sender) selected-outcome bet-type))
        
        (ok new-bet-id)
      )
      (none (err ERR_INVALID_OUTCOME))
    )
  )
)

;; Function to validate bet types and details
(define-read-only (is-valid-bet-type (bet-type (string-ascii 20)) (spread (optional int)) (over-under (optional uint)) (bet-details (optional (string-ascii 50))))
  (match bet-type
    "single" (ok true)
    "parlay" (if (is-some bet-details) (ok true) (err ERR_INVALID_BET_DETAILS))
    "over/under" (if (is-some over-under) (ok true) (err ERR_INVALID_BET_DETAILS))
    "point-spread" (if (is-some spread) (ok true) (err ERR_INVALID_BET_DETAILS))
    (err ERR_INVALID_BET_TYPE)
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
           possible-outcomes: possible-outcomes, event-resolved: true, winning-outcome: (some winning-outcome), 
           point-spread: (get point-spread betting-event), over-under: (get over-under betting-event)}
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
      (some {associated-event-id: event-id, bettor-address: bettor, bet-amount: bet-amount, chosen-outcome: chosen-outcome, bet-type: bet-type, bet-details: bet-details, payout-claimed: payout-claimed}
        (let (
              (betting-event (map-get? betting-events {event-id: event-id}))
             )
          (match betting-event
            (some {event-resolved: event-resolved, winning-outcome: winning-outcome}
              ;; Ensure the event is resolved
              (asserts! event-resolved (err ERR_EVENT_NOT_RESOLVED))
              ;; Check if the user is the winner based on bet type
              (asserts! (is-winner winning-outcome chosen-outcome bet-type bet-details betting-event) (err ERR_NOT_A_WINNER))
              ;; Ensure the winnings have not been claimed
              (asserts! (is-eq payout-claimed false) (err ERR_ALREADY_CLAIMED))
              
              ;; Transfer winnings
              (stx-transfer? (* bet-amount u2) tx-sender bettor)
              
              ;; Mark the bet as claimed
              (map-set placed-bets
                {bet-id: bet-id}
                {associated-event-id: event-id, bettor-address: bettor, bet-amount: bet-amount, 
                 chosen-outcome: chosen-outcome, bet-type: bet-type, bet-details: bet-details, payout-claimed: true}
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

;; Function to check if a bettor is a winner based on bet type and details
(define-read-only (is-winner (winning-outcome (optional (string-ascii 20))) (chosen-outcome (string-ascii 20)) (bet-type (string-ascii 20)) (bet-details (optional (string-ascii 50))) (betting-event {possible-outcomes: (list 2 (string-ascii 20)), event-resolved: bool, winning-outcome: (optional (string-ascii 20)), point-spread: (optional int), over-under: (optional uint)}))
  (match bet-type
    "single" (is-eq winning-outcome (some chosen-outcome))
    "parlay" ;; Additional logic for parlay bets will be implemented here
    "over/under" ;; Additional logic for over/under bets will be implemented here
    "point-spread" ;; Additional logic for point spread bets will be implemented here
    false ;; Default case for unknown bet type
  )
)
