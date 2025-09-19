;; Define the soulbound credential NFT
(define-non-fungible-token soulbound-credential uint)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-RECIPIENT (err u103))
(define-constant ERR-CREDENTIAL-EXPIRED (err u104))
(define-constant ERR-CREDENTIAL-REVOKED (err u105))
(define-constant ERR-TRANSFER-NOT-ALLOWED (err u106))
(define-constant ERR-INVALID-ISSUER (err u107))
(define-constant ERR-EMPTY-METADATA (err u108))

;; Data Variables
(define-data-var next-token-id uint u1)

;; Data Maps
;; Store credential metadata and status
(define-map credentials
  uint
  {
    holder: principal,
    issuer: principal,
    credential-type: (string-ascii 50),
    metadata: (string-utf8 500),
    issue-date: uint,
    expiry: (optional uint),
    status: (string-ascii 20) ;; "active", "revoked", "expired"
  }
)

;; Map holder to their credential token IDs
(define-map holder-credentials
  principal
  (list 100 uint)
)

;; Map credential types to authorized issuers
(define-map authorized-issuers
  (string-ascii 50)
  (list 50 principal)
)

;; Map issuer to credential types they can issue
(define-map issuer-permissions
  principal
  (list 20 (string-ascii 50))
)

;; Track total credentials by type
(define-map credential-type-count
  (string-ascii 50)
  uint
)

;; Private Functions

;; Check if an issuer is authorized for a specific credential type
(define-private (is-authorized-issuer-internal (issuer principal) (credential-type (string-ascii 50)))
  (let ((authorized-list (default-to (list) (map-get? authorized-issuers credential-type))))
    (is-some (index-of authorized-list issuer))
  )
)

;; Add credential to holder's list
(define-private (add-credential-to-holder (holder principal) (token-id uint))
  (let ((current-list (default-to (list) (map-get? holder-credentials holder))))
    (ok (map-set holder-credentials holder (unwrap! (as-max-len? (append current-list token-id) u100) (err u999))))
  )
)

;; Update credential type count
(define-private (increment-credential-count (credential-type (string-ascii 50)))
  (let ((current-count (default-to u0 (map-get? credential-type-count credential-type))))
    (map-set credential-type-count credential-type (+ current-count u1))
  )
)

;; Check if credential is currently valid (not expired or revoked)
(define-private (is-credential-valid (token-id uint))
  (match (map-get? credentials token-id)
    credential
    (let ((status (get status credential))
          (expiry (get expiry credential)))
      (and 
        (is-eq status "active")
        (match expiry
          exp-block (> exp-block stacks-block-height)
          true
        )
      )
    )
    false
  )
)

;; Public Functions

;; Issue a new soulbound credential
(define-public (issue-credential 
  (recipient principal) 
  (credential-type (string-ascii 50)) 
  (metadata (string-utf8 500)) 
  (expiry (optional uint))
)
  (let ((token-id (var-get next-token-id))
        (issuer tx-sender))
    
    ;; Validate inputs
    (asserts! (not (is-eq recipient issuer)) ERR-INVALID-RECIPIENT)
    (asserts! (> (len metadata) u0) ERR-EMPTY-METADATA)
    (asserts! (is-authorized-issuer-internal issuer credential-type) ERR-NOT-AUTHORIZED)
    
    ;; Validate expiry if provided
    (match expiry
      exp-block (asserts! (> exp-block stacks-block-height) ERR-CREDENTIAL-EXPIRED)
      true
    )
    
    ;; Mint the NFT to the recipient
    (try! (nft-mint? soulbound-credential token-id recipient))
    
    ;; Store credential metadata
    (map-set credentials token-id {
      holder: recipient,
      issuer: issuer,
      credential-type: credential-type,
      metadata: metadata,
      issue-date: stacks-block-height,
      expiry: expiry,
      status: "active"
    })
    
    ;; Add to holder's credential list
    (try! (add-credential-to-holder recipient token-id))
    
    ;; Update counters
    (increment-credential-count credential-type)
    (var-set next-token-id (+ token-id u1))
    
    (ok token-id)
  )
)

;; Revoke a credential (issuer only)
(define-public (revoke-credential (token-id uint) (reason (string-ascii 100)))
  (match (map-get? credentials token-id)
    credential
    (let ((issuer (get issuer credential)))
      (asserts! (is-eq tx-sender issuer) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status credential) "active") ERR-CREDENTIAL-REVOKED)
      
      ;; Update credential status
      (map-set credentials token-id (merge credential { status: "revoked" }))
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Add authorized issuer for a credential type (contract owner only)
(define-public (add-authorized-issuer (issuer principal) (credential-type (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-authorized-issuer-internal issuer credential-type)) ERR-ALREADY-EXISTS)
    
    (let ((current-issuers (default-to (list) (map-get? authorized-issuers credential-type)))
          (issuer-types (default-to (list) (map-get? issuer-permissions issuer))))
      
      ;; Add issuer to credential type
      (map-set authorized-issuers credential-type 
        (unwrap! (as-max-len? (append current-issuers issuer) u50) (err u999)))
      
      ;; Add credential type to issuer permissions
      (map-set issuer-permissions issuer
        (unwrap! (as-max-len? (append issuer-types credential-type) u20) (err u999)))
      
      (ok true)
    )
  )
)

;; Remove authorized issuer (contract owner only)
(define-public (remove-authorized-issuer (issuer principal) (credential-type (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-authorized-issuer-internal issuer credential-type) ERR-NOT-FOUND)
    
    (let ((current-issuers (default-to (list) (map-get? authorized-issuers credential-type))))
      (map-set authorized-issuers credential-type 
        (filter not-target-issuer current-issuers))
      (ok true)
    )
  )
)

;; Helper function for filtering issuers
(define-private (not-target-issuer (issuer principal))
  (not (is-eq issuer tx-sender))
)

;; Override transfer function to prevent transfers (soulbound property)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  ERR-TRANSFER-NOT-ALLOWED
)

;; SIP-009 compliant transfer function (always fails for soulbound tokens)
(define-public (transfer-memo (token-id uint) (sender principal) (recipient principal) (memo (buff 34)))
  ERR-TRANSFER-NOT-ALLOWED
)

;; Read-Only Functions

;; Verify if a holder has a valid credential of a specific type
(define-read-only (verify-credential (holder principal) (credential-type (string-ascii 50)))
  (let ((holder-creds (default-to (list) (map-get? holder-credentials holder))))
    (get found (fold check-credential-match holder-creds { target-type: credential-type, found: false }))
  )
)

;; Helper function to check if any credential matches the target type and is valid
(define-private (check-credential-match (token-id uint) (acc { target-type: (string-ascii 50), found: bool }))
  (if (get found acc)
    acc
    (match (map-get? credentials token-id)
      credential
      (if (and 
            (is-eq (get credential-type credential) (get target-type acc))
            (is-credential-valid token-id))
        { target-type: (get target-type acc), found: true }
        acc
      )
      acc
    )
  )
)

;; Get credential information
(define-read-only (get-credential-info (token-id uint))
  (map-get? credentials token-id)
)

;; Get all credentials for a holder
(define-read-only (get-holder-credentials (holder principal))
  (map-get? holder-credentials holder)
)

;; Check if an issuer is authorized for a credential type
(define-read-only (is-authorized-issuer (issuer principal) (credential-type (string-ascii 50)))
  (is-authorized-issuer-internal issuer credential-type)
)

;; Get authorized issuers for a credential type
(define-read-only (get-authorized-issuers (credential-type (string-ascii 50)))
  (map-get? authorized-issuers credential-type)
)

;; Get credential types an issuer can issue
(define-read-only (get-issuer-permissions (issuer principal))
  (map-get? issuer-permissions issuer)
)

;; Get total count of credentials by type
(define-read-only (get-credential-count (credential-type (string-ascii 50)))
  (default-to u0 (map-get? credential-type-count credential-type))
)

;; Get next token ID
(define-read-only (get-next-token-id)
  (var-get next-token-id)
)

;; SIP-009 NFT Trait Implementation
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat "https://api.soulbound-credentials.com/metadata/" (uint-to-ascii token-id))))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? soulbound-credential token-id))
)

;; Helper function to convert uint to ascii (simplified version)
(define-private (uint-to-ascii (value uint))
  (if (is-eq value u0) "0"
    (if (is-eq value u1) "1"
      (if (is-eq value u2) "2"
        (if (is-eq value u3) "3"
          (if (is-eq value u4) "4"
            (if (is-eq value u5) "5"
              (if (is-eq value u6) "6"
                (if (is-eq value u7) "7"
                  (if (is-eq value u8) "8"
                    (if (is-eq value u9) "9"
                      "unknown"
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)
