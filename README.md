#  Health Record Access & Consent Ledger (Healthcare / Data Privacy)
A decentralized solution for patient-controlled health record sharing using Stacks blockchain.

## 🎯 Purpose

This smart contract enables patients to:
- ✅ Register as patients
- 🔐 Grant and revoke consent to healthcare providers
- 📋 Maintain control over their medical records
- 🏃‍♂️ Access records anywhere

Healthcare providers can:
- 🏫 Register with their credentials
- 📝 Add medical records (with consent)
- 🔍 Access patient records (when authorized)

## 📚 Contract Functions

### Patient Functions
- `register-patient`: Register as a new patient
- `grant-consent`: Grant access to a provider
- `revoke-consent`: Revoke provider access

### Provider Functions
- `register-provider`: Register as a healthcare provider
- `add-medical-record`: Add a new medical record
- `get-medical-record`: Retrieve a medical record

### Read-Only Functions
- `get-patient-info`: Get patient registration info
- `get-provider-info`: Get provider details
- `check-consent`: Check consent status

## 🚀 Getting Started

1. Install Clarinet
2. Clone this repository
3. Run `clarinet console`
4. Deploy contract
5. Interact using provided functions

## 💡 Usage Example

```clarity
;; Register as a patient
(contract-call? .healthcare-data-privacy register-patient "John Doe")

;; Grant consent to provider
(contract-call? .healthcare-data-privacy grant-consent 'PROVIDER-ADDRESS u100)
```

## 🔒 Security

- All operations require appropriate authentication
- Consent is time-bound and revocable
- Record access is strictly controlled
```
