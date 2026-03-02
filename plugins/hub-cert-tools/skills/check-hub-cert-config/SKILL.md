---
name: check-hub-cert-config
description: Checks hub cluster kube-apiserver certificate configuration and its compatibility with ACM. Detects certificate type, validates configuration, and provides recommendations for both pre-installation and post-installation scenarios.
invocation_pattern: "^/check-hub-cert-config"
---

# Check Hub Cluster Certificate Configuration

This skill checks hub cluster kube-apiserver certificate configuration and its impact on ACM. It detects certificate type, validates ACM configuration, and provides tailored recommendations based on your cluster's current state.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Parse Arguments**
   - Extract `--kubeconfig` parameter if provided
   - If not provided, use the `KUBECONFIG` environment variable
   - If neither provided, display error and usage instructions

2. **Execute the automated workflow**
   - Execute: `bash <skill-dir>/scripts/check-hub-cert-config.sh --kubeconfig <path>`
   - The script will:
     - Detect ACM installation status
     - Analyze certificate type and configuration
     - Provide appropriate recommendations

3. **Present results to the user**
   - The script will display the analysis in 5 steps:
     - **Step 1: Cluster Information** - API endpoint, OCP version, user
     - **Step 2: Cluster Kube APIServer Certificates** - Certificate type, details, root CA status, complete chain
     - **Step 3: ACM Status and Configuration** - ACM status, version, ServerVerificationStrategy configuration
       - Use ✅ for INSTALLED status
       - Use ℹ️  for NOT INSTALLED status (this is informational, not an error)
       - Use ⚠️  for OPERATOR ONLY status
     - **Step 4: ACM Certificate Management Analysis** - Recommended ServerVerificationStrategy, comparison with current
     - **Step 5: Analysis Summary** - Compatibility assessment and recommendations

4. **Provide a user-friendly summary**
   After the script output, summarize the key findings using this structure:
   - **Cluster Overview** - Basic cluster information
   - **Certificate Analysis** - Certificate type, details, and chain
   - **ACM Status** - Installation status (version, namespace, MultiClusterHub)
   - **Server Verification Strategy** - Current vs recommended strategy
   - **Final Verdict** - Compatibility status and recommendations

   **Terminology Guidelines:**
   - Use "ACM Status" for the installation status and runtime information
   - Use "Server Verification Strategy" (not "Certificate Configuration") for the ServerVerificationStrategy settings
   - Clearly separate "status" (current state) from "configuration" (settings)

   **Presentation Guidelines:**
   - When presenting multiple options, present them equally without marking any as "(Recommended)"
   - Let users choose based on their specific situation and plans
   - The script output already provides the necessary context for decision-making

## Usage

**With kubeconfig parameter:**
```bash
/check-hub-cert-config --kubeconfig /path/to/kubeconfig
```

**Using KUBECONFIG environment variable:**
```bash
export KUBECONFIG=/path/to/kubeconfig
/check-hub-cert-config
```

## When to Use This Skill

Invoke this skill when you need to:
- **Plan ACM installation** on a cluster
- **Verify ACM configuration** with certificates
- **Troubleshoot ACM/certificate issues**
- **Understand certificate compatibility** with ACM

## What This Skill Does

### Workflow Steps

**Step 1: Cluster Information**
- Displays kubeconfig path, API endpoint, OCP version, current user

**Step 2: Cluster Kube APIServer Certificates**
- Determines certificate type (OpenShift-Managed, Red Hat-managed, Custom CA)
- Extracts certificate details (subject, issuer, validity)
- Checks if root CA is included
- Displays complete certificate chain

**Step 3: ACM Status and Configuration**
- Checks ACM installation status
- Detects MultiClusterHub status and version
- Shows current ServerVerificationStrategy (if ACM installed)

**Step 4: ACM Certificate Management Analysis**
- Recommends ServerVerificationStrategy based on certificate type
- Compares current configuration with recommendation (if ACM installed)

**Step 5: Analysis Summary**
- **Pre-Installation**: Safety evaluation and installation recommendations
- **Post-Installation**: Configuration verification and compatibility check

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ `oc` CLI installed
- ✅ `openssl` CLI available

---

## Analysis Outputs

### For Clusters WITHOUT ACM (Pre-Installation)

**Certificate Type Assessment:**
- Safety evaluation for ACM installation
- Custom certificate configuration guidance
- ACM configuration recommendations

### For Clusters WITH ACM (Post-Installation)

**Status and Configuration Verification:**
- ACM installation status and version
- Certificate type compatibility check
- Server verification strategy validation
- Troubleshooting guidance if needed

---

## Certificate Types and ACM Compatibility

| Certificate Type | Pre-Installation | Post-Installation |
|------------------|------------------|-------------------|
| OpenShift-Managed | ✅ Safe (don't change cert type later) | ✅ Verify no cert changes planned |
| Red Hat-managed | ✅ Safe with UseSystemTruststore | ✅ Verify UseSystemTruststore |
| Custom - Well-Known CA | ✅ Safe with root CA included | ✅ Verify configuration |
| Custom - Private CA | ✅ Safe with root CA included | ✅ Verify CA bundle config |

---

## Related Skills

- **assess-hub-cert-change**: Assess the risk of changing hub cluster certificates and get step-by-step guidance for safe certificate transitions

## Troubleshooting

**KUBECONFIG not persisting:**
- ✅ Specify with --kubeconfig parameter

**oc command not found:**
- ✅ Ensure OpenShift CLI is installed

**Permission denied errors:**
- ✅ Verify kubeconfig has appropriate cluster permissions
