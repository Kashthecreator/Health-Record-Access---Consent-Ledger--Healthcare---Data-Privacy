(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PATIENT (err u101))
(define-constant ERR-INVALID-PROVIDER (err u102))
(define-constant ERR-NO-CONSENT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-EMERGENCY-EXPIRED (err u105))
(define-constant ERR-INVALID-JUSTIFICATION (err u106))
(define-constant ACCESS-SUCCESS "SUCCESS")
(define-constant ACCESS-DENIED "DENIED")
(define-constant EMERGENCY-DURATION u144)

(define-data-var contract-owner principal tx-sender)
(define-data-var audit-log-counter uint u0)
(define-data-var emergency-counter uint u0)

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

(define-map audit-logs
  uint
  {
    patient: principal,
    provider: principal,
    action: (string-ascii 20),
    status: (string-ascii 10),
    timestamp: uint,
    record-id: (optional uint)
  }
)

(define-map emergency-access
  uint
  {
    provider: principal,
    patient: principal,
    issued: uint,
    expires: uint,
    justification: (optional (string-ascii 200)),
    justified: bool
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

(define-private (log-audit-entry (patient principal) (provider principal) (action (string-ascii 20)) (status (string-ascii 10)) (record-id (optional uint)))
  (let ((log-id (+ (var-get audit-log-counter) u1)))
    (var-set audit-log-counter log-id)
    (map-set audit-logs log-id {
      patient: patient,
      provider: provider,
      action: action,
      status: status,
      timestamp: stacks-block-height,
      record-id: record-id
    })
    log-id
  )
)

(define-public (access-medical-record (patient principal) (record-id uint))
  (let ((caller tx-sender)
        (consent (map-get? consent-records {patient: patient, provider: caller})))
    (match consent
      consent-data 
        (if (and (get granted consent-data) (> (get expiry consent-data) stacks-block-height))
          (let ((log-id (log-audit-entry patient caller "RECORD_ACCESS" ACCESS-SUCCESS (some record-id))))
            (ok (map-get? medical-records {patient: patient, record-id: record-id}))
          )
          (let ((log-id (log-audit-entry patient caller "RECORD_ACCESS" ACCESS-DENIED (some record-id))))
            ERR-NO-CONSENT
          )
        )
      (let ((log-id (log-audit-entry patient caller "RECORD_ACCESS" ACCESS-DENIED (some record-id))))
        ERR-NO-CONSENT
      )
    )
  )
)

(define-read-only (get-medical-record (patient principal) (record-id uint))
  (let ((caller tx-sender)
        (consent (unwrap! (map-get? consent-records {patient: patient, provider: caller}) ERR-NO-CONSENT)))
    (asserts! (get granted consent) ERR-NO-CONSENT)
    (asserts! (> (get expiry consent) stacks-block-height) ERR-NO-CONSENT)
    (ok (map-get? medical-records {patient: patient, record-id: record-id}))
  )
)

(define-read-only (get-audit-log (log-id uint))
  (map-get? audit-logs log-id)
)

(define-read-only (get-patient-audit-logs (patient principal) (start-id uint) (end-id uint))
  (let ((logs (list)))
    (fold check-patient-log (unwrap-panic (as-max-len? (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u10)) logs)
  )
)

(define-private (check-patient-log (id uint) (acc (list 10 (optional {patient: principal, provider: principal, action: (string-ascii 20), status: (string-ascii 10), timestamp: uint, record-id: (optional uint)}))))
  (let ((log-entry (map-get? audit-logs id)))
    (match log-entry
      entry 
        (if (is-eq (get patient entry) tx-sender)
          (unwrap-panic (as-max-len? (append acc (some entry)) u10))
          acc
        )
      acc
    )
  )
)

(define-public (request-emergency-access (patient principal))
  (let ((caller tx-sender)
        (emergency-id (+ (var-get emergency-counter) u1)))
    (asserts! (is-some (map-get? healthcare-providers caller)) ERR-INVALID-PROVIDER)
    (asserts! (is-some (map-get? patients patient)) ERR-INVALID-PATIENT)
    (var-set emergency-counter emergency-id)
    (ok (map-set emergency-access emergency-id {
      provider: caller,
      patient: patient,
      issued: stacks-block-height,
      expires: (+ stacks-block-height EMERGENCY-DURATION),
      justification: none,
      justified: false
    }))
  )
)

(define-public (justify-emergency-access (emergency-id uint) (justification (string-ascii 200)))
  (let ((caller tx-sender)
        (emergency (unwrap! (map-get? emergency-access emergency-id) ERR-NOT-AUTHORIZED)))
    (asserts! (is-eq caller (get provider emergency)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len justification) u10) ERR-INVALID-JUSTIFICATION)
    (ok (map-set emergency-access emergency-id 
      (merge emergency {
        justification: (some justification),
        justified: true
      })
    ))
  )
)

(define-public (emergency-access-record (patient principal) (record-id uint) (emergency-id uint))
  (let ((caller tx-sender)
        (emergency (unwrap! (map-get? emergency-access emergency-id) ERR-NOT-AUTHORIZED)))
    (asserts! (is-eq caller (get provider emergency)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq patient (get patient emergency)) ERR-INVALID-PATIENT)
    (asserts! (> (get expires emergency) stacks-block-height) ERR-EMERGENCY-EXPIRED)
    (let ((log-id (log-audit-entry patient caller "EMERGENCY_ACCESS" ACCESS-SUCCESS (some record-id))))
      (ok (map-get? medical-records {patient: patient, record-id: record-id}))
    )
  )
)

(define-read-only (get-emergency-access (emergency-id uint))
  (map-get? emergency-access emergency-id)
)

(define-read-only (check-emergency-validity (emergency-id uint))
  (let ((emergency (map-get? emergency-access emergency-id)))
    (match emergency
      emergency-data
        (and 
          (> (get expires emergency-data) stacks-block-height)
          (get justified emergency-data)
        )
      false
    )
  )
)