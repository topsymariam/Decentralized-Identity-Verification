;; Decentralized Identity Verification Contract
;; A comprehensive identity management system with verification, reputation, and recovery

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_IDENTITY_EXISTS (err u101))
(define-constant ERR_IDENTITY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_VERIFIER (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_VERIFICATION_EXPIRED (err u105))
(define-constant ERR_INVALID_CHALLENGE (err u106))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u107))
(define-constant ERR_INVALID_INPUT (err u108))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var min-verification-threshold uint u3)
(define-data-var verification-fee uint u1000000) ;; 1 STX in microSTX

;; Data Maps
(define-map identities principal {
  hash: (buff 32),
  created-at: uint,
  verified: bool,
  reputation-score: uint,
  verification-count: uint,
  last-activity: uint
})

(define-map verifiers principal {
  active: bool,
  reputation: uint,
  verifications-made: uint,
  stake: uint,
  joined-at: uint
})

(define-map verifications {identity: principal, verifier: principal} {
  verified-at: uint,
  expires-at: uint,
  verification-type: (string-ascii 20),
  metadata: (optional (string-ascii 100))
})

(define-map identity-challenges principal {
  challenge: (buff 32),
  created-at: uint,
  solved: bool
})

(define-map recovery-guardians {identity: principal, guardian: principal} {
  approved: bool,
  added-at: uint
})

(define-map pending-recoveries principal {
  new-hash: (buff 32),
  approvals: uint,
  expires-at: uint,
  initiated-by: principal
})

;; Input Validation Functions
(define-private (validate-hash (hash (buff 32)))
  (and (> (len hash) u0) (<= (len hash) u32)))

(define-private (validate-string (str (string-ascii 20)))
  (and (> (len str) u0) (<= (len str) u20)))

(define-private (validate-metadata (meta (optional (string-ascii 100))))
  (match meta
    some-meta (and (> (len some-meta) u0) (<= (len some-meta) u100))
    true))

(define-private (validate-fee (fee uint))
  (and (> fee u0) (<= fee u100000000))) ;; Max 100 STX

(define-private (validate-threshold (threshold uint))
  (and (> threshold u0) (<= threshold u10)))

(define-private (validate-principal (principal-addr principal))
  (not (is-eq principal-addr 'SP000000000000000000002Q6VF78)))

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER))

(define-private (is-contract-active)
  (var-get contract-active))

(define-private (is-authorized-verifier (verifier principal))
  (match (map-get? verifiers verifier)
    verifier-data (get active verifier-data)
    false))

;; Utility Functions
(define-private (get-current-time)
  block-height)

(define-private (calculate-reputation-boost (verifier principal))
  (match (map-get? verifiers verifier)
    verifier-data (/ (get reputation verifier-data) u10)
    u0))

;; Core Identity Functions
(define-public (create-identity (identity-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (is-contract-active) ERR_NOT_AUTHORIZED)
    (asserts! (validate-hash identity-hash) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? identities caller)) ERR_IDENTITY_EXISTS)
    (ok (map-set identities caller {
      hash: identity-hash,
      created-at: (get-current-time),
      verified: false,
      reputation-score: u0,
      verification-count: u0,
      last-activity: (get-current-time)
    }))))

(define-public (update-identity (new-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (is-contract-active) ERR_NOT_AUTHORIZED)
    (asserts! (validate-hash new-hash) ERR_INVALID_INPUT)
    (match (map-get? identities caller)
      identity-data
      (ok (map-set identities caller
        (merge identity-data {
          hash: new-hash,
          last-activity: (get-current-time)
        })))
      ERR_IDENTITY_NOT_FOUND)))

;; Verifier Management
(define-public (register-verifier (stake uint))
  (let ((caller tx-sender))
    (asserts! (is-contract-active) ERR_NOT_AUTHORIZED)
    (asserts! (>= stake u5000000) ERR_NOT_AUTHORIZED) ;; Min 5 STX stake
    (try! (stx-transfer? stake caller (as-contract tx-sender)))
    (ok (map-set verifiers caller {
      active: true,
      reputation: u100,
      verifications-made: u0,
      stake: stake,
      joined-at: (get-current-time)
    }))))

(define-public (deactivate-verifier)
  (let ((caller tx-sender))
    (match (map-get? verifiers caller)
      verifier-data
      (begin
        (try! (as-contract (stx-transfer? (get stake verifier-data) tx-sender caller)))
        (ok (map-delete verifiers caller)))
      ERR_INVALID_VERIFIER)))

;; Verification Process
(define-public (verify-identity (identity principal) (verification-type (string-ascii 20)) 
                               (metadata (optional (string-ascii 100))))
  (let ((caller tx-sender)
        (current-time (get-current-time)))
    (asserts! (is-contract-active) ERR_NOT_AUTHORIZED)
    (asserts! (validate-principal identity) ERR_INVALID_INPUT)
    (asserts! (validate-string verification-type) ERR_INVALID_INPUT)
    (asserts! (validate-metadata metadata) ERR_INVALID_INPUT)
    (asserts! (is-authorized-verifier caller) ERR_INVALID_VERIFIER)
    (asserts! (is-some (map-get? identities identity)) ERR_IDENTITY_NOT_FOUND)
    
    ;; Charge verification fee
    (try! (stx-transfer? (var-get verification-fee) identity (as-contract tx-sender)))
    
    ;; Record verification
    (map-set verifications {identity: identity, verifier: caller} {
      verified-at: current-time,
      expires-at: (+ current-time u52560), ;; ~1 year in blocks
      verification-type: verification-type,
      metadata: metadata
    })
    
    ;; Update verifier stats
    (match (map-get? verifiers caller)
      verifier-data
      (map-set verifiers caller
        (merge verifier-data {
          verifications-made: (+ (get verifications-made verifier-data) u1),
          reputation: (+ (get reputation verifier-data) u5)
        }))
      true)
    
    ;; Update identity verification status
    (match (map-get? identities identity)
      identity-data
      (let ((new-count (+ (get verification-count identity-data) u1))
            (reputation-boost (calculate-reputation-boost caller)))
        (map-set identities identity
          (merge identity-data {
            verification-count: new-count,
            verified: (>= new-count (var-get min-verification-threshold)),
            reputation-score: (+ (get reputation-score identity-data) u10 reputation-boost),
            last-activity: current-time
          })))
      true)
    
    (ok true)))

;; Challenge System
(define-public (create-challenge (challenge-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (validate-hash challenge-hash) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? identities caller)) ERR_IDENTITY_NOT_FOUND)
    (ok (map-set identity-challenges caller {
      challenge: challenge-hash,
      created-at: (get-current-time),
      solved: false
    }))))

(define-public (solve-challenge (identity principal) (solution (buff 32)))
  (let ((caller tx-sender))
    (asserts! (validate-principal identity) ERR_INVALID_INPUT)
    (asserts! (validate-hash solution) ERR_INVALID_INPUT)
    (match (map-get? identity-challenges identity)
      challenge-data
      (if (and (is-eq (get challenge challenge-data) solution)
               (not (get solved challenge-data)))
        (begin
          (map-set identity-challenges identity
            (merge challenge-data {solved: true}))
          (ok true))
        ERR_INVALID_CHALLENGE)
      ERR_IDENTITY_NOT_FOUND)))

;; Recovery System
(define-public (add-recovery-guardian (guardian principal))
  (let ((caller tx-sender))
    (asserts! (validate-principal guardian) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? identities caller)) ERR_IDENTITY_NOT_FOUND)
    (asserts! (is-some (map-get? identities guardian)) ERR_IDENTITY_NOT_FOUND)
    (ok (map-set recovery-guardians {identity: caller, guardian: guardian} {
      approved: false,
      added-at: (get-current-time)
    }))))

(define-public (approve-guardian (identity principal))
  (let ((caller tx-sender))
    (asserts! (validate-principal identity) ERR_INVALID_INPUT)
    (match (map-get? recovery-guardians {identity: identity, guardian: caller})
      guardian-data
      (ok (map-set recovery-guardians {identity: identity, guardian: caller}
        (merge guardian-data {approved: true})))
      ERR_NOT_AUTHORIZED)))

(define-public (initiate-recovery (identity principal) (new-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (validate-principal identity) ERR_INVALID_INPUT)
    (asserts! (validate-hash new-hash) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? recovery-guardians {identity: identity, guardian: caller})) ERR_NOT_AUTHORIZED)
    (ok (map-set pending-recoveries identity {
      new-hash: new-hash,
      approvals: u1,
      expires-at: (+ (get-current-time) u1008), ;; ~1 week
      initiated-by: caller
    }))))

;; Read-only Functions
(define-read-only (get-identity (user principal))
  (map-get? identities user))

(define-read-only (get-verifier (user principal))
  (map-get? verifiers user))

(define-read-only (is-verified (user principal))
  (match (map-get? identities user)
    identity-data (get verified identity-data)
    false))

(define-read-only (get-verification-status (identity principal) (verifier principal))
  (match (map-get? verifications {identity: identity, verifier: verifier})
    verification-data
    (some {
      verified: (< (get-current-time) (get expires-at verification-data)),
      type: (get verification-type verification-data),
      verified-at: (get verified-at verification-data)
    })
    none))

(define-read-only (get-reputation-score (user principal))
  (match (map-get? identities user)
    identity-data (get reputation-score identity-data)
    u0))

(define-read-only (get-contract-info)
  {
    active: (var-get contract-active),
    min-threshold: (var-get min-verification-threshold),
    verification-fee: (var-get verification-fee),
    owner: CONTRACT_OWNER
  })

;; Admin Functions
(define-public (set-verification-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (validate-fee new-fee) ERR_INVALID_INPUT)
    (ok (var-set verification-fee new-fee))))

(define-public (set-min-verification-threshold (threshold uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (validate-threshold threshold) ERR_INVALID_INPUT)
    (ok (var-set min-verification-threshold threshold))))

(define-public (toggle-contract-status)
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (ok (var-set contract-active (not (var-get contract-active))))))

(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))))