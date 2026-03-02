# Usage Examples

This document provides practical examples for using the ACM certificate management skills.

## Check Hub Cluster Certificate Configuration

### Basic Usage

```bash
# Using KUBECONFIG environment variable
export KUBECONFIG=/path/to/kubeconfig
/check-hub-cert-config

# Using explicit kubeconfig parameter
/check-hub-cert-config --kubeconfig /path/to/kubeconfig

# Using relative path
/check-hub-cert-config --kubeconfig ./kubeconfig.prod
```

### Real-World Scenarios

#### Scenario 1: Planning ACM Installation on Hub Cluster

You want to install ACM on a hub cluster and need to check if the current kube-apiserver certificate configuration is compatible.

```bash
/check-hub-cert-config --kubeconfig cluster-hub.kubeconfig
```

**Expected Output:**
- Hub cluster certificate type detection (OpenShift-Managed, Red Hat-managed, Custom CA)
- ACM installation safety assessment
- Recommended ServerVerificationStrategy
- Pre-installation guidance specific to the certificate type

#### Scenario 2: Troubleshooting Managed Cluster Import Failures

Managed clusters are failing to import with certificate validation errors on the hub cluster.

```bash
/check-hub-cert-config --kubeconfig hub-cluster.kubeconfig
```

**What to Check:**
- Is ServerVerificationStrategy configured correctly for the hub's certificate type?
- Is the root CA included in the hub cluster's certificate chain?
- Does the certificate configuration match ACM's requirements?

#### Scenario 3: Verifying Current Configuration Before Changes

Before making any certificate changes on a hub cluster with ACM installed, verify the current state.

```bash
/check-hub-cert-config --kubeconfig production-hub.kubeconfig
```

**Key Information:**
- Current certificate type and configuration
- Certificate chain completeness
- Root CA inclusion status
- ServerVerificationStrategy configuration
- Recommendations for your specific setup

### Understanding the Output

The skill provides analysis in 5 steps:

1. **Step 1: Cluster Information** - Kubeconfig path, API endpoint, OCP version, current user
2. **Step 2: Cluster Kube APIServer Certificates** - Certificate type, details, validity, chain analysis
3. **Step 3: ACM Status** - Installation status, version, MultiClusterHub details
4. **Step 4: ACM Certificate Configuration Check** - Recommended and current ServerVerificationStrategy
5. **Step 5: Configuration Summary** - Compatibility assessment, recommendations, next steps

---

## Assess Hub Certificate Change

### Basic Usage

```bash
# Using KUBECONFIG environment variable (most common)
export KUBECONFIG=/path/to/kubeconfig
/assess-hub-cert-change --new-cert /path/to/new-certificate.pem

# Using explicit kubeconfig parameter
/assess-hub-cert-change --kubeconfig /path/to/kubeconfig --new-cert /path/to/new-cert.pem

# Using relative paths
/assess-hub-cert-change --kubeconfig ./kubeconfig.prod --new-cert ./certs/new-api-cert.pem
```

### Real-World Scenarios

#### Scenario 1: Certificate Renewal (Same CA)

You need to renew an expiring certificate with a new certificate from the same CA.

```bash
# Current certificate expires soon, renewing with same CA
export KUBECONFIG=~/clusters/prod-hub/kubeconfig
/assess-hub-cert-change --new-cert ~/certs/renewed-api-cert.pem
```

**Expected Assessment:**
- **Scenario**: Certificate Renewal
- **Risk Level**: 🟢 LOW
- **Procedure**: A (Simple Certificate Update)
- **Impact**: Brief API server restart, minimal disruption

#### Scenario 2: New Intermediate CA (Same Root)

Your CA provider is rotating intermediate certificates (e.g., Let's Encrypt R3 → E1).

```bash
export KUBECONFIG=production.kubeconfig
/assess-hub-cert-change --new-cert new-cert-with-E1-intermediate.pem
```

**Expected Assessment:**
- **Scenario**: New Intermediate CA
- **Risk Level**: 🟢 LOW or 🟡 MEDIUM (depends on root CA inclusion)
- **Procedure**: A or B (may need to add root CA first)
- **Impact**: No managed cluster disruption if procedure followed

#### Scenario 3: Root CA Change (High Risk)

You're migrating from OpenShift-managed certificates to custom certificates, or changing CA providers.

```bash
export KUBECONFIG=hub.kubeconfig
/assess-hub-cert-change --new-cert custom-ca-cert-chain.pem
```

**Expected Assessment:**
- **Scenario**: New Root CA
- **Risk Level**: 🔴 HIGH
- **Procedure**: C or D (3-phase update required)
- **WARNING**: Direct update will cause managed cluster disruption!

#### Scenario 4: Checking Impact on Offline Clusters

You have some managed clusters that are temporarily offline and want to assess certificate change impact.

```bash
export KUBECONFIG=hub-with-offline-clusters.kubeconfig
/assess-hub-cert-change --new-cert new-certificate.pem
```

**What to Look For:**
- **Managed Cluster Status** section shows which clusters are offline
- Additional warnings about offline clusters
- Risk assessment includes warnings that offline clusters cannot receive new CA bundles
- Recommendation to bring clusters online before proceeding

### Understanding the Output

The skill provides comprehensive assessment:

1. **Current Certificate Configuration** - Your hub's current certificate setup
2. **ACM Status and Server Verification Strategy** - Current ACM configuration
3. **Managed Cluster Status** - Health check of all managed clusters (flags offline clusters)
4. **Planned Certificate Change** - Analysis of the new certificate
5. **Change Assessment** - What's changing (root CA, intermediate CA)
6. **Risk Assessment** - Risk level and impact analysis
7. **Recommended Procedure** - Complete step-by-step instructions with actual commands

### Tips for Safe Certificate Changes

**Before Running the Assessment:**
- ✅ Ensure you have the complete certificate chain (leaf + intermediates + root)
- ✅ Verify the new certificate is valid and not expired
- ✅ Have cluster admin access to the hub cluster

**After Receiving the Assessment:**
- ✅ Read the complete procedure before starting
- ✅ For HIGH-risk changes, schedule a maintenance window (60-90 minutes)
- ✅ Ensure all managed clusters are AVAILABLE before starting (or accept that offline clusters will lose connectivity)
- ✅ Have the private key ready for the new certificate
- ✅ Test on a non-production environment first if possible

**During the Change:**
- ✅ Follow the procedure steps exactly as provided
- ✅ Don't skip steps (especially for 3-phase procedures)
- ✅ Monitor managed cluster status throughout
- ✅ Wait for propagation periods (typically 5-15 minutes)

---

## Common Workflows

### Workflow 1: Planning ACM Installation with Custom Certificates

```bash
# Step 1: Check current certificate configuration
/check-hub-cert-config --kubeconfig new-hub.kubeconfig

# Review output and ensure certificate is compatible
# If root CA is missing, add it to the certificate chain before installing ACM

# Step 2: Proceed with ACM installation
# (ACM installation steps)

# Step 3: Verify configuration after installation
/check-hub-cert-config --kubeconfig new-hub.kubeconfig
```

### Workflow 2: Certificate Rotation on Existing ACM Hub

```bash
# Step 1: Check current configuration
/check-hub-cert-config --kubeconfig prod-hub.kubeconfig

# Step 2: Assess the planned certificate change
/assess-hub-cert-change --kubeconfig prod-hub.kubeconfig --new-cert new-cert.pem

# Step 3: Review risk assessment and procedure

# Step 4: Execute the recommended procedure
# (Follow the step-by-step instructions from the assessment output)

# Step 5: Verify the change was successful
/check-hub-cert-config --kubeconfig prod-hub.kubeconfig
```

---

## Adding Your Own Examples

When you add a new skill, consider adding usage examples here to help users understand:
- Common use cases and real-world scenarios
- Command syntax with actual examples
- Expected outputs and what to look for
- Integration with ACM workflows
- Common troubleshooting patterns
