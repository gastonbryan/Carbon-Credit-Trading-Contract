# Carbon Credit Auditing & Verification System

## Overview
This PR introduces a comprehensive **Carbon Credit Auditing and Verification System** to the existing carbon credit trading contract. This independent feature enhances trust and transparency by allowing third-party auditors to verify carbon credits, issue compliance certificates, and maintain auditor reputation scores.

## Technical Implementation
The auditing system adds the following key components:

### Core Data Structures
- **`authorized-auditors`**: Maps auditor principals to their credentials, certifications, audit history, and reputation scores
- **`audit-records`**: Tracks individual audit processes from initiation to completion with detailed findings and verification scores  
- **`compliance-certificates`**: Manages certificates issued for verified credits with expiry dates and compliance grades

### Key Functions Added

#### Auditor Management
- `authorize-auditor`: Contract owner can authorize new auditors with their certifications
- `revoke-auditor`: Remove auditor authorization
- `is-authorized-auditor`: Check auditor authorization status

#### Audit Process
- `initiate-audit`: Authorized auditors can start auditing carbon credits  
- `complete-audit`: Submit audit findings with verification scores (0-100) and compliance levels
- `get-active-audit-for-credit`: Prevent duplicate audits for the same credit

#### Compliance Certification
- `issue-compliance-certificate`: Issue certificates for high-quality audits (score ≥70)
- `revoke-certificate`: Contract owner or issuing auditor can revoke certificates
- `is-certificate-valid`: Check certificate validity and expiry

#### Transparency Functions
- `get-auditor-info`: View auditor credentials and statistics
- `get-audit-record`: Access detailed audit information
- `get-compliance-certificate`: Retrieve certificate details
- `get-audit-statistics`: System-wide audit metrics
- `get-credit-audit-history`: Complete audit trail for specific credits

### Enhanced Contract Statistics
The existing `get-contract-stats` function now includes:
- Total audits completed
- Total certificates issued  
- Next audit and certificate IDs

## Testing & Validation
- ✅ Contract passes `clarinet check` with proper Clarity v3 compliance
- ✅ Comprehensive test suite covering all auditing functionality
- ✅ Error handling for edge cases and unauthorized access
- ✅ CI/CD pipeline configured for automated validation

## Key Features
- **Independent Operation**: No cross-contract calls or trait dependencies
- **Proper Error Handling**: 7 new error constants (u113-u118) for comprehensive error coverage
- **Reputation System**: Dynamic auditor reputation scoring based on verification quality
- **Certificate Management**: Time-based certificate validity with revocation capabilities
- **Access Control**: Multi-level authorization (contract owner, authorized auditors)
- **Audit Trail**: Complete history and transparency for all audit activities

## Environmental Impact
This auditing system strengthens the carbon credit ecosystem by:
- **Enhanced Credibility**: Third-party verification increases market confidence
- **Compliance Tracking**: Automated certificate management ensures regulatory compliance
- **Quality Assurance**: Reputation scoring incentivizes high-quality audits
- **Transparency**: Complete audit trails prevent fraud and double-counting
- **Market Efficiency**: Trusted verification reduces transaction costs and barriers