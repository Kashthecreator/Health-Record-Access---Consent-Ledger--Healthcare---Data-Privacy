(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PATIENT (err u101))
(define-constant ERR-INVALID-PROVIDER (err u102))
(define-constant ERR-NO-CONSENT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))

(define-data-var contract-owner principal tx-sender)

(define-map patients 
  principal 
  {
    name: (string-ascii 50),
    active: bool
  }
)

(define-map healthcare-providers
  principal
  {
    name: (string-ascii 50),
    license: (string-ascii 20),
    active: bool
  }
)

(define-map consent-records
  {
    patient: principal,
    provider: principal
  }
  {
    granted: bool,
    timestamp: uint,
    expiry: uint
  }
)

(define-map medical-records
  {
    patient: principal,
    record-id: uint
  }
  {
    provider: principal,
    data-hash: (string-ascii 64),
    timestamp: uint,
    description: (string-ascii 100)
  }
)

(define-public (register-patient (name (string-ascii 50)))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? patients caller)) ERR-ALREADY-EXISTS)
    (ok (map-set patients caller {
      name: name,
      active: true
    }))
  )
)

(define-public (register-provider (name (string-ascii 50)) (license (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? healthcare-providers caller)) ERR-ALREADY-EXISTS)
    (ok (map-set healthcare-providers caller {
      name: name,
      license: license,
      active: true
    }))
  )
)

(define-public (grant-consent (provider principal) (expiry uint))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? patients caller)) ERR-INVALID-PATIENT)
    (asserts! (is-some (map-get? healthcare-providers provider)) ERR-INVALID-PROVIDER)
    (ok (map-set consent-records 
      {patient: caller, provider: provider}
      {
        granted: true,
        timestamp: stacks-block-height,
        expiry: expiry
      }
    ))
  )
)

(define-public (revoke-consent (provider principal))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? patients caller)) ERR-INVALID-PATIENT)
    (ok (map-set consent-records 
      {patient: caller, provider: provider}
      {
        granted: false,
        timestamp: stacks-block-height,
        expiry: u0
      }
    ))
  )
)

(define-public (add-medical-record 
    (patient principal)
    (record-id uint)
    (data-hash (string-ascii 64))
    (description (string-ascii 100)))
  (let (
    (caller tx-sender)
    (consent (unwrap! (map-get? consent-records {patient: patient, provider: caller}) ERR-NO-CONSENT))
  )
    (asserts! (is-some (map-get? healthcare-providers caller)) ERR-INVALID-PROVIDER)
    (asserts! (get granted consent) ERR-NO-CONSENT)
    (asserts! (> (get expiry consent) stacks-block-height) ERR-NO-CONSENT)
    (ok (map-set medical-records
      {patient: patient, record-id: record-id}
      {
        provider: caller,
        data-hash: data-hash,
        timestamp: stacks-block-height,
        description: description
      }
    ))
  )
)

(define-read-only (get-patient-info (patient principal))
  (map-get? patients patient)
)

(define-read-only (get-provider-info (provider principal))
  (map-get? healthcare-providers provider)
)

(define-read-only (check-consent (patient principal) (provider principal))
  (map-get? consent-records {patient: patient, provider: provider})
)

(define-read-only (get-medical-record (patient principal) (record-id uint))
  (let ((caller tx-sender)
        (consent (unwrap! (map-get? consent-records {patient: patient, provider: caller}) ERR-NO-CONSENT)))
    (asserts! (get granted consent) ERR-NO-CONSENT)
    (asserts! (> (get expiry consent) stacks-block-height) ERR-NO-CONSENT)
    (ok (map-get? medical-records {patient: patient, record-id: record-id}))
  )
)