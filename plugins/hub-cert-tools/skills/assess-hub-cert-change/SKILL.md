---
name: assess-hub-cert-change
description: "Assess the risk of changing hub cluster kube-apiserver certificates on clusters with ACM. Evaluates impact of certificate type changes, rotations, root CA changes, and intermediate CA changes. Provides risk analysis and mitigation guidance. Accepts --kubeconfig (optional, defaults to KUBECONFIG env var) and --new-cert (required) parameters."
invocation_pattern: "^/assess-hub-cert-change"
allowed-tools: [Bash, Read]
---

# ACM Certificate Change Risk Assessment

This skill helps you assess the risk and impact of changing kube-apiserver certificates on OpenShift clusters with ACM installed. It compares your current certificate with a planned new certificate and provides step-by-step guidance for a safe transition.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Parse Arguments**
   - Extract `--kubeconfig` parameter (optional, defaults to KUBECONFIG env var)
   - Extract `--new-cert` parameter (required - path to new certificate file)
   - If `--new-cert` is missing, display error and usage instructions

2. **Validate Inputs**
   - Check that kubeconfig file exists and is readable
   - Check that new certificate file exists and is valid PEM format
   - Test connectivity to cluster using kubeconfig

3. **Execute Assessment Workflow**
   - Run the assessment script: `bash <skill-dir>/scripts/assess-hub-cert-change.sh --kubeconfig <path> --new-cert <path>`
   - The script will:
     - Analyze current certificate configuration from the cluster
     - Detect ACM status and configuration
     - Check managed cluster status (identifies offline/unavailable clusters)
     - Analyze the new certificate file
     - Compare current vs new certificates
     - Generate comprehensive risk assessment report with warnings for offline clusters

4. **Present Results**
   - Display the script output which includes:
     - Current certificate configuration
     - ACM status and server verification strategy
     - Managed cluster status (with warnings for offline clusters)
     - Planned certificate change details
     - Change assessment (what's changing)
     - Risk assessment (LOW/MEDIUM/HIGH with additional warnings for offline clusters)
     - Recommended procedure with **complete step-by-step instructions**

   **IMPORTANT:** Always include the full detailed procedure with all commands from the script output. Do NOT summarize the steps - users need the complete copy-paste-ready commands with:
   - Exact command syntax
   - Actual file paths and values (e.g., `ca-chain.crt`, actual API FQDN)
   - All comments and notes
   - Complete heredoc blocks for YAML resources

   Present the procedure in formatted code blocks so users can easily copy and execute the commands.

   **DO NOT ADD:** Pre-execution checklists, post-execution checklists, or other extra sections beyond what the script outputs. Present the assessment results and procedure directly.

## Parameters

### Required Parameters

**`--new-cert <path>`**
- Path to the new certificate file you plan to install
- Must be in PEM format
- Should include complete certificate chain (leaf + intermediates + root)
- Can be partial chain, but assessment will note if root CA is missing

### Optional Parameters

**`--kubeconfig <path>`**
- Path to kubeconfig file for accessing the ACM hub cluster
- If not provided, uses the `KUBECONFIG` environment variable
- If neither provided, the skill will display an error

## Usage Examples

### Basic Usage (KUBECONFIG env var set)

```bash
# Set kubeconfig environment variable
export KUBECONFIG=/path/to/kubeconfig

# Run assessment with new certificate
/assess-hub-cert-change --new-cert /path/to/new-certificate.pem
```

### Explicit Kubeconfig

```bash
# Run assessment with explicit kubeconfig and new certificate
/assess-hub-cert-change --kubeconfig /path/to/kubeconfig --new-cert /path/to/new-cert.pem
```

### Example Output

```text
╔═══════════════════════════════════════════════════════════════╗
║   Hub Certificate Change Assessment                           ║
╚═══════════════════════════════════════════════════════════════╝

━━━ Current Certificate Configuration

Certificate Type: Custom Certificate (Well-Known CA)
Subject: CN=api.example.com
Issuer: CN=R3,O=Let's Encrypt,C=US
Root CA: CN=ISRG Root X1,O=Internet Security Research Group,C=US

━━━ ACM Status and Server Verification Strategy

Verification Strategy: Auto-Detected CA Bundle

━━━ Managed Cluster Status

All 3 managed clusters are AVAILABLE

━━━ Planned Certificate Change

New Subject: CN=api.example.com
New Issuer: CN=E1,O=Let's Encrypt,C=US
New Root CA: CN=ISRG Root X1,O=Internet Security Research Group,C=US

━━━ Change Assessment

What's changing:
  • Root CA: No change
  • Intermediate CA: Changing from R3 to E1

━━━ Risk Assessment

Risk Level: 🟢 LOW

Impact on ACM Hub:
  • Certificate update requires API server restart
  • Brief connection interruption during update

Impact on Managed Clusters:
  • No impact with correct procedure
  • Clusters remain AVAILABLE throughout

━━━ Recommended Procedure

Procedure: Simple Certificate Update

Step 1: Create the certificate secret
  oc create secret tls api-server-cert --cert=new-cert.pem --key=/path/to/new-key.pem -n openshift-config

Step 2: Update APIServer configuration
  oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["api.example.com"],"servingCertificate":{"name":"api-server-cert"}}]}}}'

Step 3: Verify managed clusters remain AVAILABLE
  # Watch for 15 minutes and ensure all clusters show AVAILABLE=True
  oc get managedclusters -w

═══════════════════════════════════════════════════════════════
```

## Certificate Change Scenarios

The skill identifies and provides guidance for three main scenarios:

### Scenario 1: Certificate Renewal
- Renewing an expiring certificate
- Same root CA and intermediate CA
- **Risk**: 🟢 LOW
- **Procedure**: A (Simple Certificate Update)

### Scenario 2: New Intermediate CA
- Updating to a certificate with a new intermediate CA
- Root CA remains the same
- **Risk**: 🟢 LOW to 🟡 MEDIUM (depends on root CA inclusion)
- **Procedure**: A or B (depends on ServerVerificationStrategy)

### Scenario 3: New Root CA
- Updating to a certificate with a different root CA
- **Risk**: 🔴 HIGH
- **Procedure**: C or D (3-phase update required)
- **WARNING**: Never update certificate directly with root CA change!

## Procedures

Based on the scenario and ACM configuration, the skill recommends one of four procedures:

- **Procedure A**: Simple Certificate Update
- **Procedure B**: Add Root CA and Update Certificate
- **Procedure C**: 3-Phase Root CA Update with Auto-Detection
- **Procedure D**: 3-Phase Root CA Update with Custom CA Bundles

Each procedure includes complete step-by-step instructions.

## ServerVerificationStrategy

ACM supports three strategies for hub certificate verification. For detailed information about these strategies, see the **check-hub-cert-config** skill.

**Quick Reference:**
- **UseAutoDetectedCABundle** (default) - ACM auto-detects CA bundle from hub certificate
- **UseSystemTruststore** - Uses managed cluster system trust stores (best for well-known public CAs)
- **UseCustomCABundles** - Uses explicitly configured CA bundles (maximum control)

## When to Use This Skill

Invoke this skill when you need to:

- **Plan certificate updates** on ACM hub clusters
- **Assess risk** before changing certificates
- **Understand impact** on managed clusters
- **Get step-by-step guidance** for certificate changes
- **Verify compatibility** of new certificates with ACM

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ ACM installed on the cluster (or planning to install)
- ✅ `oc` CLI installed and configured
- ✅ New certificate file in PEM format
- ✅ Understanding of planned certificate change

## Workflow

```text
1. Parse arguments (--kubeconfig, --new-cert)
   ↓
2. Validate inputs (files exist, certificates valid)
   ↓
3. Analyze current certificate (retrieve from cluster, determine type)
   ↓
4. Detect ACM configuration (check installation, get ServerVerificationStrategy)
   ↓
5. Analyze new certificate (extract chain, root CA)
   ↓
6. Compare certificates (determine scenario)
   ↓
7. Generate comprehensive report (risk + procedure)
```

## Troubleshooting

**Error: "Missing required argument: --new-cert"**
- ✅ Provide path to new certificate file using `--new-cert` parameter

**Error: "No kubeconfig specified"**
- ✅ Set KUBECONFIG environment variable OR use `--kubeconfig` parameter

**Error: "File does not contain a valid PEM certificate"**
- ✅ Verify new certificate file is in PEM format (contains "BEGIN CERTIFICATE")

**Warning: "Root CA not included in certificate chain"**
- ℹ️ This is informational - assessment will still complete
- ℹ️ For certain scenarios, you may need to obtain the complete chain

**Failed to analyze current certificate**
- ✅ Verify kubeconfig has cluster access: `oc whoami`
- ✅ Check cluster connectivity to API server

## Related Skills

- **check-hub-cert-config**: Check hub cluster certificate configuration and ACM compatibility

## References

- [ACM ServerVerificationStrategy Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.15/html-single/clusters/index#set-hub-kube-api-server)
- [OpenShift API Server Certificates](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/configuring-certificates#api-server-certificates)
