# ACM Certificate Change Risk Assessment

Assess the risk and impact of changing kube-apiserver certificates on OpenShift clusters with ACM. Get step-by-step guidance for safe certificate transitions.

## Important Restrictions

### ⚠️ Red Hat-managed Certificates Cannot Be Changed

This skill will **block** certificate change attempts on clusters with **Red Hat-managed certificates** (e.g., ROSA, ARO clusters). These certificates:
- Are automatically issued and renewed by Red Hat
- Use well-known CAs (e.g., Let's Encrypt)
- Are part of the managed service offering
- **Cannot be replaced with custom certificates**

If you need custom certificates, use a self-managed OpenShift cluster instead.

### ℹ️ Simplified Procedure for Non-ACM Clusters

When ACM is **not installed**, this skill will:
- Provide a link to the standard OpenShift documentation for certificate updates
- Skip ACM-specific procedures and managed cluster checks
- Recommend running `/check-hub-cert-config` after certificate update if you plan to install ACM later

## What This Skill Does

This skill helps you safely plan and execute certificate changes on ACM hub clusters by:

- **Analyzing** your current certificate configuration
- **Comparing** current vs. planned certificates
- **Identifying** the change scenario (renewal, new intermediate CA, or new root CA)
- **Assessing** risk level (LOW/MEDIUM/HIGH)
- **Recommending** the appropriate procedure to follow
- **Providing** complete step-by-step instructions (for ACM-enabled clusters)
- **Blocking** unsupported changes (Red Hat-managed certificates)

## Quick Start

```bash
# Basic usage (with KUBECONFIG environment variable set)
/assess-hub-cert-change --new-cert /path/to/new-certificate.pem

# With explicit kubeconfig
/assess-hub-cert-change --kubeconfig /path/to/kubeconfig --new-cert /path/to/new-cert.pem
```

## Certificate Change Scenarios

The skill identifies three main scenarios and recommends the appropriate procedure:

| Scenario | What's Changing | Risk Level | Procedure |
|----------|----------------|------------|-----------|
| **1: Certificate Renewal** | Leaf certificate only (same CAs) | 🟢 LOW | A: Simple Update |
| **2: New Intermediate CA** | Intermediate CA (same root) | 🟢 LOW - 🟡 MEDIUM | A or B |
| **3: New Root CA** | Root CA | 🔴 HIGH | C or D (3-phase) |

## Procedures Overview

### Procedure OCP: Standard OpenShift Certificate Update
- **When**: ACM is not installed
- **Action**: Follow standard OpenShift documentation
- **Reference**: Provides link to OCP docs for certificate configuration
- **Note**: Run `/check-hub-cert-config` after update if planning to install ACM

### Procedure A: Simple Certificate Update
- Direct certificate update
- Use when managed clusters already trust the CA chain
- Lowest risk, fastest to execute

### Procedure B: Add Root CA and Update
- Add root CA to trusted bundles first
- Then update certificate
- For scenarios where root CA isn't currently in the chain

### Procedure C: 3-Phase Update (Auto-Detection)
- For root CA changes with UseAutoDetectedCABundle strategy
- Phase 1: Add new CA temporarily
- Phase 2: Update certificate
- Phase 3: Remove temporary configuration

### Procedure D: 3-Phase Update (Custom Bundles)
- For root CA changes with UseCustomCABundles strategy
- Phase 1: Add new CA to bundle list
- Phase 2: Update certificate
- Phase 3: Remove old CA from list

## Example Output

```text
╔═══════════════════════════════════════════════════════════════╗
║   ACM Certificate Change Risk Assessment                      ║
╚═══════════════════════════════════════════════════════════════╝

━━━ Step 1: Current Certificate Configuration

Certificate Type: OpenShift-Managed Certificate
Issuer: CN=kube-apiserver-lb-signer
Root CA: CN=kube-apiserver-lb-signer (self-signed)

━━━ Step 2: Planned Certificate Change

New Issuer: CN=R3,O=Let's Encrypt,C=US
New Root CA: CN=ISRG Root X1,O=Internet Security Research Group,C=US

━━━ Step 3: Change Analysis

Scenario: Scenario 3 - New Root CA

What's changing:
  • Root CA: Changing
  • Intermediate CA: Changing
  • Certificate Type: OpenShift-Managed → Custom Certificate

━━━ Step 4: Risk Assessment

Risk Level: 🔴 HIGH

WARNING: Do not update certificate directly - may cause immediate disruption!

━━━ Step 5: Recommended Procedure

Follow: Procedure C - 3-Phase Root CA Update with Auto-Detection

[Complete step-by-step instructions provided...]
```

## Parameters

### Required

- `--new-cert <path>` - Path to new certificate file (PEM format)

### Optional

- `--kubeconfig <path>` - Path to kubeconfig (defaults to $KUBECONFIG)

## Prerequisites

- OpenShift cluster with ACM installed (or planned)
- Valid kubeconfig with cluster admin access
- New certificate file in PEM format
- `oc` CLI installed

## When to Use This Skill

Use this skill before making any certificate changes to:

✅ Understand the risk level of your planned change
✅ Get the correct procedure for your scenario
✅ Avoid managed cluster disruption
✅ Plan maintenance windows appropriately
✅ Prepare rollback procedures

## ACM ServerVerificationStrategy

The skill automatically detects your ACM configuration and tailors recommendations accordingly:

- **UseAutoDetectedCABundle** (default) - ACM auto-detects CA bundle from hub cert
- **UseSystemTruststore** - Uses managed cluster system trust stores
- **UseCustomCABundles** - Uses explicitly configured CA bundles

## Risk Levels Explained

### 🟢 LOW Risk
- No special preparation needed
- Minimal disruption (brief API restart)
- Managed clusters remain available
- Simple rollback if needed

### 🟡 MEDIUM Risk
- Preparation required before certificate update
- Potential for temporary unavailability if procedure not followed
- Configuration changes needed
- Recovery time: 5-15 minutes if issues occur

### 🔴 HIGH Risk
- Multi-phase procedure required
- Direct update will cause immediate cluster disruption
- Careful planning and execution essential
- Total time: 30-60 minutes for complete procedure

## Features

- **Automated Analysis** - Compares current and planned certificates automatically
- **Scenario Detection** - Identifies which of 3 scenarios applies
- **Risk Assessment** - Evaluates impact on hub and managed clusters
- **Managed Cluster Status** - Checks for offline/unavailable clusters
- **Procedure Mapping** - Recommends the correct procedure based on your configuration
- **Complete Instructions** - Provides full step-by-step guidance with actual commands

## Related Skills

- **check-hub-cert-config** - Check hub cluster certificate configuration and ACM compatibility before making changes

## Troubleshooting

**"Missing required argument: --new-cert"**
→ You must provide the new certificate file path

**"No kubeconfig specified"**
→ Set KUBECONFIG environment variable or use --kubeconfig parameter

**"File does not contain a valid PEM certificate"**
→ Verify the file is in PEM format and contains "BEGIN CERTIFICATE"

**"Root CA not included in certificate chain"**
→ This is informational - the assessment will still complete and advise accordingly

## Best Practices

1. **Always run this assessment** before making certificate changes on ACM hub clusters
2. **Review the complete procedure** before starting
3. **Schedule maintenance windows** based on risk level (HIGH = 60-90 minutes)
4. **Have rollback procedures ready** in case of issues
5. **Verify certificate chains** are complete (leaf + intermediates + root)
6. **Test on non-production** environments first when possible
7. **Monitor managed clusters** for at least 15 minutes after changes

## Support

For detailed technical documentation, refer to:
- [ACM Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/)
- [OpenShift Certificate Configuration](https://docs.redhat.com/en/documentation/openshift_container_platform/)
