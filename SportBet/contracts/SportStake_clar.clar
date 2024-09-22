;; Smart contract for a simple sports betting system on Stacks blockchain using Clarity.
;; This contract includes functionalities for creating events, placing bets, and resolving them.

;; Define contract owner
(define-data-var contract-owner principal tx-sender)

(define-data-var total-event-count uint u0) ;; Counter for total number of events
(define-data-var total-bet-count uint u0) ;; Counter for total number of bets

(define-map betting-events
  {
    event-id: uint
  }
  {
    event-title: (string-ascii 100), ;; Title of the sporting event
    possible-outcomes: (list 2 (string-ascii 20)), ;; Possible outcomes (e.g., ["Team A", "Team B"])
    event-resolved: bool, ;; Whether the event has been resolved
    winning-outcome: (optional (string-ascii 20)), ;; Winning outcome if resolved
    total-score: (optional uint), ;; Total score for over/under bets
    point-spread: (optional int), ;; Point spread for the event
    total-staked: uint, ;; Total amount staked for the event
    outcome-staked: (map (string-ascii 20) uint) ;; Amount staked on each outcome
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
    bet-details: (optional (string-ascii 50)), ;; Additional details for complex bets (e.g., combined event IDs or over/under value)
    payout-claimed: bool ;; Whether the winnings have been claimed
  }
)

;; Error codes for the contract
(define-constant ERR_INVALID_OUTCOME u100)
(define-constant ERR_EVENT_NOT_RESOLVED u101)
(define-constant ERR_NOT_A_WINNER u102)
(define-constant ERR_ALREADY_CLAIMED u103)
(define-constant ERR_UNAUTHORIZED u104)
(define-constant ERR_INVALID_BET_TYPE u105)
(define-constant ERR_INVALID_BET_DETAILS u106)
(define-constant ERR_MISSING_DATA u107)
(define-constant ERR_INVALID_INPUT u108)

;; Function to create a new betting event
(define-public (create-betting-event (title (string-ascii 100)) (outcomes (list 2 (string-ascii 20))) (point-spread (optional int)) (total-score (optional uint)))
  (let (
        (new-event-id (+ (var-get total-event-count) u1))
       )
    (begin
      ;; Ensure two unique outcomes are provided
      (asserts! (is-eq (len outcomes) u2) (err ERR_INVALID_OUTCOME))
      
      ;; Store the new event in the map with initial staked amounts of zero
      (map-set betting-events
        {event-id: new-event-id}
        {event-title: title, possible-outcomes: outcomes, event-resolved: false, winning-outcome: none, 
         total-score: total-score, point-spread: point-spread, total-staked: u0, outcome-staked: {}}
      )
      
      ;; Update the event counter
      (var-set total-event-count new-event-id)
      
      ;; Emit event log
      (print {event: "event-created", id: new-event-id, title: title})
      
      (ok new-event-id)
    )
  )
)

;; Function to place a bet on an event
(define-public (place-bet-on-event (event-id uint) (selected-outcome (string-ascii 20)) (bet-type (string-ascii 20)) (bet-details (optional (string-ascii 50))))
  (let (
        (new-bet-id (+ (var-get total-bet-count) u1))
        (betting-event (unwrap! (map-get? betting-events {event-id: event-id}) (err ERR_INVALID_OUTCOME)))
       )
    ;; Check if the selected outcome is valid
    (asserts! (or (is-eq (get 0 (get possible-outcomes betting-event)) selected-outcome)
                  (is-eq (get 1 (get possible-outcomes betting-event)) selected-outcome)) (err ERR_INVALID_OUTCOME))
    ;; Ensure the event is not resolved yet
    (asserts! (is-eq (get event-resolved betting-event) false) (err ERR_EVENT_NOT_RESOLVED))
    ;; Validate bet type and details
    (asserts! (is-valid-bet-type bet-type bet-details) (err ERR_INVALID_BET_TYPE))
    
    ;; Calculate new total staked amount
    (let (
          (new-total-staked (+ (get total-staked betting-event) (stx-get-balance tx-sender)))
          (new-outcome-staked (+ (get selected-outcome (get outcome-staked betting-event) u0) (stx-get-balance tx-sender)))
         )
      ;; Update event with new staked amounts
      (map-set betting-events
        {event-id: event-id}
        {event-title: (get event-title betting-event),
         possible-outcomes: (get possible-outcomes betting-event), event-resolved: false, winning-outcome: none,
         total-score: (get total-score betting-event),
         point-spread: (get point-spread betting-event),
         total-staked: new-total-staked, outcome-staked: (merge-outcome-staked (get outcome-staked betting-event) selected-outcome (stx-get-balance tx-sender))}
      )
      ;; Save the bet information
      (map-set placed-bets
        {bet-id: new-bet-id}
        {associated-event-id: event-id, bettor-address: tx-sender, bet-amount: (stx-get-balance tx-sender), 
         chosen-outcome: selected-outcome, bet-type: bet-type, bet-details: bet-details, payout-claimed: false}
      )
      
      ;; Update the bet counter
      (var-set total-bet-count new-bet-id)
      
      ;; Emit event log
      (print {event: "bet-placed", bet-id: new-bet-id, event-id: event-id, bettor: tx-sender, amount: (stx-get-balance tx-sender), outcome: selected-outcome, type: bet-type})
      
      (ok new-bet-id)
    )
  )
)

;; Function to merge new staked amount with existing outcome stakes
(define-read-only (merge-outcome-staked (outcome-staked (map (string-ascii 20) uint)) (selected-outcome (string-ascii 20)) (amount uint))
  (if (is-eq (get selected-outcome outcome-staked) none)
    (merge outcome-staked {selected-outcome: amount})
    (merge outcome-staked {selected-outcome: (+ (get selected-outcome outcome-staked u0) amount)})
  )
)

;; Function to calculate odds for an outcome
(define-read-only (calculate-odds (event-id uint) (selected-outcome (string-ascii 20)))
  (let ((event (unwrap! (map-get? betting-events {event-id: event-id}) (err u0))))
    (if (is-eq (get total-staked event) u0)
      (err u0) ;; Avoid division by zero
      (ok (/ (* (get total-staked event) u100) (get selected-outcome (get outcome-staked event) u1))) ;; Odds calculation
    )
  )
)

;; Function to resolve a betting event and declare a winning outcome
(define-public (resolve-betting-event (event-id uint) (winning-outcome (string-ascii 20)) (total-score (optional uint)))
  (let (
        (betting-event (unwrap! (map-get? betting-events {event-id: event-id}) (err ERR_INVALID_OUTCOME)))
       )
    ;; Ensure only the contract owner can resolve
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Check if the selected winning outcome is valid
    (asserts! (or (is-eq (get 0 (get possible-outcomes betting-event)) winning-outcome)
                  (is-eq (get 1 (get possible-outcomes betting-event)) winning-outcome)) (err ERR_INVALID_OUTCOME))
    ;; Ensure the event is not already resolved
    (asserts! (is-eq (get event-resolved betting-event) false) (err ERR_EVENT_NOT_RESOLVED))
    
    ;; Update the event with the winning outcome and total score
    (map-set betting-events
      {event-id: event-id}
      {event-title: (get event-title betting-event),
       possible-outcomes: (get possible-outcomes betting-event), event-resolved: true, winning-outcome: (some winning-outcome),
       total-score: total-score,
       point-spread: (get point-spread betting-event),
       total-staked: (get total-staked betting-event), 
       outcome-staked: (get outcome-staked betting-event)}
    )
    
    ;; Emit event log
    (print {event: "event-resolved", event-id: event-id, winning-outcome: winning-outcome})
    
    (ok event-id)
  )
)

;; Function to claim winnings from a resolved bet with complex logic for parlay, over/under, and point spread bets
(define-public (claim-bet-winnings (bet-id uint))
  (let (
        (bet-details (unwrap! (map-get? placed-bets {bet-id: bet-id}) (err ERR_INVALID_OUTCOME)))
       )
    (let (
          (betting-event (unwrap! (map-get? betting-events {event-id: (get associated-event-id bet-details)}) (err ERR_INVALID_OUTCOME)))
         )
      ;; Ensure the event is resolved
      (asserts! (get event-resolved betting-event) (err ERR_EVENT_NOT_RESOLVED))
      ;; Ensure the winnings have not been claimed
      (asserts! (is-eq (get payout-claimed bet-details) false) (err ERR_ALREADY_CLAIMED))
      ;; Calculate payout based on bet type
      (let ((payout 
              (match (get bet-type bet-details)
                "single" 
                  (if (is-eq (get winning-outcome betting-event) (some (get chosen-outcome bet-details)))
                    (unwrap! (calculate-single-payout (get associated-event-id bet-details) (get chosen-outcome bet-details) (get bet-amount bet-details)) (err ERR_INVALID_OUTCOME))
                    (err ERR_NOT_A_WINNER))
                
                "parlay" 
                  (unwrap! (calculate-parlay-payout (get bet-details bet-details) (get bet-amount bet-details)) (err ERR_INVALID_OUTCOME))
                
                "over/under" 
                  (unwrap! (calculate-over-under-payout (get bet-details bet-details) (get total-score betting-event) (get bet-amount bet-details)) (err ERR_INVALID_OUTCOME))
                
                "point-spread" 
                  (unwrap! (calculate-point-spread-payout (get chosen-outcome bet-details) (get point-spread betting-event) (get bet-amount bet-details)) (err ERR_INVALID_OUTCOME))
                
                (err ERR_INVALID_BET_TYPE)
              )
            ))
        ;; Transfer winnings
        (stx-transfer? payout tx-sender (get bettor-address bet-details))
        
        ;; Mark the bet as claimed
        (map-set placed-bets
          {bet-id: bet-id}
          {associated-event-id: (get associated-event-id bet-details), bettor-address: (get bettor-address bet-details), bet-amount: (get bet-amount bet-details), 
           chosen-outcome: (get chosen-outcome bet-details), bet-type: (get bet-type bet-details), bet-details: (get bet-details bet-details), payout-claimed: true}
        )
        
        ;; Emit event log
        (print {event: "winnings-claimed", bet-id: bet-id, amount: payout})
        
        (ok payout)
      )
    )
  )
)

;; Function to calculate payout for single bets
(define-read-only (calculate-single-payout (event-id uint) (chosen-outcome (string-ascii 20)) (bet-amount uint))
  (let ((odds (unwrap! (calculate-odds event-id chosen-outcome) ERR_INVALID_INPUT)))
    (ok (/ (* bet-amount odds) u100))
  )
)

;; Function to calculate payout for parlay bets
(define-read-only (calculate-parlay-payout (bet-details (optional (string-ascii 50))) (bet-amount uint))
  ;; Example logic for parlay payout calculation: Combine odds for all events in the parlay
  (if (is-none bet-details)
    (err ERR_INVALID_BET_DETAILS)
    (let ((events (split-string (unwrap bet-details "") ",")))
      (ok (/ (* bet-amount (reduce (lambda (acc odds) (* acc (parse-int odds))) u1 (map get-parlay-odds events))) u100))
    )
  )
)

;; Helper function to get odds for each event in a parlay bet
(define-read-only (get-parlay-odds (event-str (string-ascii 20)))
  (let ((event-id (parse-int event-str)))
    (unwrap! (calculate-odds event-id (get 0 (unwrap! (map-get? betting-events {event-id: event-id}) (err u0)))) u0)
  )
)

;; Function to calculate payout for over/under bets
(define-read-only (calculate-over-under-payout (bet-details (optional (string-ascii 50))) (total-score (optional uint)) (bet-amount uint))
  (if (or (is-none bet-details) (is-none total-score))
    (err ERR_MISSING_DATA)
    (let ((threshold (parse-int (unwrap bet-details ""))))
      (if (> (unwrap total-score u0) threshold)
        (ok (* bet-amount u2)) ;; Double payout for winning over bet
        (ok (/ bet-amount u2)) ;; Half payout for losing over bet
      )
    )
  )
)

;; Function to calculate payout for point spread bets
(define-read-only (calculate-point-spread-payout (chosen-outcome (string-ascii 20)) (point-spread (optional int)) (bet-amount uint))
  (if (is-none point-spread)
    (err ERR_MISSING_DATA)
    (let ((spread (unwrap point-spread 0)))
      (if (>= spread 0)
        (ok (* bet-amount u2)) ;; Double payout for beating the spread
        (ok (/ bet-amount u2)) ;; Half