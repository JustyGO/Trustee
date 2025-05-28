;; System Constants
(define-constant sys-admin tx-sender)
(define-constant OVERFLOW-ERROR u127)
(define-constant ACCESS-DENIED u403)
(define-constant INVALID-STATE u422)
(define-constant RESOURCE-LOCKED u423)

;; Dynamic State Management
(define-data-var round-counter uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var min-threshold uint u5)
(define-data-var ticket-price uint u150)
(define-data-var session-active bool false)
(define-data-var entropy-modifier uint u0)
(define-data-var max-capacity uint u75)

;; Storage Mappings
(define-map session-roster { epoch: uint } (list 75 principal))
(define-map wallet-stakes { epoch: uint, holder: principal } uint)
(define-map victory-records { epoch: uint } { winner: principal, reward: uint, timestamp: uint })
(define-map session-metadata { epoch: uint } { total-entries: uint, closure-time: uint })

;; Utility Functions
(define-private (generate-pseudo-random (ceiling uint))
  (let (
    (entropy-val (var-get entropy-modifier))
    (block-entropy (+ stx-liquid-supply burn-block-height))
    (sender-buff (unwrap-panic (to-consensus-buff? tx-sender)))
    (sender-entropy (+ (len sender-buff) u113))
    (combined-entropy (+ entropy-val (+ block-entropy sender-entropy)))
  )
    (var-set entropy-modifier (+ entropy-val u23))
    (mod combined-entropy ceiling)
  )
)

(define-private (determine-winner (epoch-id uint)) 
  (let (
    (participant-roster (unwrap-panic (map-get? session-roster { epoch: epoch-id })))
    (roster-size (len participant-roster))
    (selection-index (generate-pseudo-random roster-size))
  )
    (ok (unwrap-panic (element-at participant-roster selection-index)))
  )
)

;; Arithmetic Safety Layer
(define-private (secure-add (x uint) (y uint))
  (let ((sum (+ x y)))
    (asserts! (>= sum x) (err OVERFLOW-ERROR))
    (asserts! (>= sum y) (err OVERFLOW-ERROR))
    (ok sum)
  )
)

(define-private (secure-multiply (base uint) (multiplier uint))
  (if (is-eq multiplier u0)
    (ok u0)
    (let ((product (* base multiplier)))
      (asserts! (is-eq (/ product multiplier) base) (err OVERFLOW-ERROR))
      (ok product)
    )
  )
)

;; Core Protocol Functions

(define-public (initialize-session)
  (begin
    (asserts! (is-eq tx-sender sys-admin) (err ACCESS-DENIED))
    (asserts! (not (var-get session-active)) (err INVALID-STATE))
    (var-set session-active true)
    (ok true)
  )
)

(define-public (acquire-stakes (stake-count uint))
  (let (
    (current-epoch (var-get round-counter))
    (unit-cost (var-get ticket-price))
    (total-payment (try! (secure-multiply unit-cost stake-count)))
  )
    (asserts! (var-get session-active) (err INVALID-STATE))
    (asserts! (> stake-count u0) (err INVALID-STATE))
    
    (try! (stx-transfer? total-payment tx-sender (as-contract tx-sender)))
    
    (let (
      (existing-stakes (map-get? wallet-stakes { epoch: current-epoch, holder: tx-sender }))
      (previous-count (default-to u0 existing-stakes))
      (updated-count (try! (secure-add previous-count stake-count)))
    )
      (begin
        (if (is-none existing-stakes)
          (let (
            (current-roster (default-to (list) (map-get? session-roster { epoch: current-epoch })))
            (expanded-roster (unwrap! 
              (as-max-len? (append current-roster tx-sender) u75) 
              (err RESOURCE-LOCKED)
            ))
          )
            (map-set session-roster { epoch: current-epoch } expanded-roster)
          )
          true
        )
        
        (map-set wallet-stakes 
          { epoch: current-epoch, holder: tx-sender } 
          updated-count
        )
        
        (let ((enhanced-treasury (try! (secure-add (var-get treasury-balance) total-payment))))
          (var-set treasury-balance enhanced-treasury)
          (ok updated-count)
        )
      )
    )
  )
)

(define-public (conclude-session)
  (let (
    (active-epoch (var-get round-counter))
    (prize-pool (var-get treasury-balance))
    (current-time burn-block-height)
  )
    (asserts! (is-eq tx-sender sys-admin) (err ACCESS-DENIED))
    (asserts! (var-get session-active) (err INVALID-STATE))
    (asserts! (> prize-pool u0) (err INVALID-STATE))
    
    (let ((selected-winner (unwrap! (determine-winner active-epoch) (err INVALID-STATE))))
      (try! (as-contract (stx-transfer? prize-pool tx-sender selected-winner)))
      
      (map-set victory-records
        { epoch: active-epoch }
        { winner: selected-winner, reward: prize-pool, timestamp: current-time }
      )
      
      (map-set session-metadata
        { epoch: active-epoch }
        { 
          total-entries: (len (default-to (list) (map-get? session-roster { epoch: active-epoch }))),
          closure-time: current-time
        }
      )
      
      (var-set round-counter (+ active-epoch u1))
      (var-set treasury-balance u0)
      (var-set session-active false)
      (ok selected-winner)
    )
  )
)

(define-public (emergency-halt)
  (begin
    (asserts! (is-eq tx-sender sys-admin) (err ACCESS-DENIED))
    (var-set session-active false)
    (ok true)
  )
)

(define-public (adjust-parameters (new-price uint) (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender sys-admin) (err ACCESS-DENIED))
    (asserts! (not (var-get session-active)) (err INVALID-STATE))
    (var-set ticket-price new-price)
    (var-set min-threshold new-threshold)
    (ok true)
  )
)

;; Query Interface

(define-read-only (get-system-status)
  {
    current-epoch: (var-get round-counter),
    treasury-amount: (var-get treasury-balance),
    session-running: (var-get session-active),
    stake-price: (var-get ticket-price),
    participation-threshold: (var-get min-threshold),
    max-participants: (var-get max-capacity)
  }
)

(define-read-only (get-victory-data (epoch-number uint))
  (map-get? victory-records { epoch: epoch-number })
)

(define-read-only (get-holder-stakes (participant principal) (epoch-number uint))
  (default-to u0 (map-get? wallet-stakes { epoch: epoch-number, holder: participant }))
)

(define-read-only (get-session-info (epoch-number uint))
  (map-get? session-metadata { epoch: epoch-number })
)

(define-read-only (get-participant-list (epoch-number uint))
  (map-get? session-roster { epoch: epoch-number })
)

(define-read-only (calculate-estimated-payout)
  (let (
    (current-treasury (var-get treasury-balance))
    (current-roster (default-to (list) (map-get? session-roster { epoch: (var-get round-counter) })))
    (participant-count (len current-roster))
  )
    (if (> participant-count u0)
      (some { 
        estimated-reward: current-treasury,
        total-participants: participant-count,
        odds: (/ u10000 participant-count)
      })
      none
    )
  )
)