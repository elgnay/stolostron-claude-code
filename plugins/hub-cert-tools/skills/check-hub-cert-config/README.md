# Check Hub Cluster Certificate Configuration

Check hub cluster kube-apiserver certificate configuration and its compatibility with ACM. Detect certificate types, validate configuration, and get tailored recommendations for your cluster's current state.

## What This Skill Does

This skill helps you understand and verify your hub cluster certificate configuration by:

- **Detecting** ACM installation status and version
- **Analyzing** kube-apiserver certificate type and configuration
- **Validating** certificate chain completeness (root CA inclusion)
- **Checking** ServerVerificationStrategy configuration
- **Recommending** optimal configuration based on certificate type
- **Providing** pre-installation and post-installation guidance

## Quick Start

```bash
# Using KUBECONFIG environment variable
export KUBECONFIG=/path/to/kubeconfig
/check-hub-cert-config

# With explicit kubeconfig parameter
/check-hub-cert-config --kubeconfig /path/to/kubeconfig
```

## Certificate Types Detected

The skill automatically identifies your certificate type:

| Certificate Type | Description | Recommended Strategy |
|------------------|-------------|---------------------|
| **OpenShift-Managed** | Default OpenShift certificates | UseAutoDetectedCABundle |
| **Red Hat-managed** | Well-known CA (e.g., Let's Encrypt via ROSA) | UseSystemTruststore |
| **Custom - Well-Known CA** | Custom cert from public CA | UseAutoDetectedCABundle or UseSystemTruststore |
| **Custom - Private CA** | Custom cert from private/self-signed CA | UseAutoDetectedCABundle (with root CA) |

## ServerVerificationStrategy

ACM supports three strategies for verifying hub cluster certificates:

### UseAutoDetectedCABundle (default)
- **How it works**: ACM automatically detects the CA bundle from the hub certificate
- **Best for**: OpenShift-Managed and Custom certificates with complete CA chain
- **Requirements**: Certificate chain should include root CA
- **Flexibility**: Most flexible for certificate changes when root CA is included

### UseSystemTruststore
- **How it works**: Uses the managed cluster's system trust store
- **Best for**: Red Hat-managed and Custom certificates from well-known CAs
- **Requirements**: Root CA must be in system trust store (true for public CAs)
- **Advantages**: No additional configuration needed for well-known CAs

### UseCustomCABundles
- **How it works**: Uses explicitly configured CA bundles in KlusterletConfig
- **Best for**: Advanced scenarios requiring specific CA control
- **Requirements**: Manual CA bundle configuration
- **Advantages**: Maximum control over trusted CAs

## Analysis Scenarios

### Pre-Installation (ACM not installed)

The skill evaluates whether it's safe to install ACM and provides:
- ✅ Safety assessment for ACM installation
- 📋 Configuration recommendations
- ⚠️  Warnings about potential issues
- 📝 Next steps for installation

### Post-Installation (ACM installed)

The skill verifies your current configuration and provides:
- ✅ Compatibility verification
- 🔍 ServerVerificationStrategy validation
- ⚠️  Configuration mismatch detection
- 🛠️  Remediation guidance if needed

## Example Output

```text
═══════════════════════════════════════════════════════════════

Step 1: Cluster Information

Kubeconfig:    /path/to/kubeconfig
API Endpoint:  https://api.example.com:6443
OCP Version:   4.16.0
Current User:  admin

Step 2: Cluster Kube APIServer Certificates

Certificate Type: Custom Certificate (Private CA)
Subject:          CN=api.example.com
Issuer:           CN=Intermediate CA
Valid Until:      Dec 31 23:59:59 2026 GMT
Root CA Included: Yes

Certificate Chain:
  [1] Subject: CN=api.example.com
      Issuer:  CN=Intermediate CA

  [2] Subject: CN=Intermediate CA
      Issuer:  CN=Root CA

  [3] Subject: CN=Root CA
      Issuer:  CN=Root CA

Step 3: ACM Status

✓ ACM Status: INSTALLED
  Version:   2.15.0
  Namespace: open-cluster-management
  Name:      multiclusterhub
  Status:    Running

Step 4: ACM Certificate Configuration Check

Recommended ServerVerificationStrategy:

  Recommended: UseAutoDetectedCABundle
  • Private CA certificates require auto-detection with full CA chain

  Current: UseAutoDetectedCABundle
  Status: ✓ Matches recommendation

═══════════════════════════════════════════════════════════════

Step 5: Configuration Summary

OCP API Endpoint: https://api.example.com:6443
OCP Version: 4.16.0
Certificate Type: Custom-SelfSigned
Root CA Included: Yes
ACM: Installed (Version 2.15.0)
ServerVerificationStrategy: UseAutoDetectedCABundle

✓ Configuration: Compatible

Root CA is included in certificate chain
  • ACM will automatically detect and distribute the CA bundle to managed clusters
  • No additional configuration required
```

## When to Use This Skill

Use this skill when you need to:

✅ **Plan ACM installation** - Verify certificate compatibility before installing
✅ **Verify configuration** - Check if ACM is properly configured for your certificates
✅ **Troubleshoot issues** - Diagnose managed cluster import failures
✅ **Understand certificates** - Learn about your hub cluster's certificate setup
✅ **Prepare for changes** - Understand current state before certificate updates

## Parameters

### Optional

- `--kubeconfig <path>` - Path to kubeconfig (defaults to $KUBECONFIG environment variable)

## Prerequisites

- OpenShift cluster access with valid kubeconfig
- `oc` CLI installed and configured
- `openssl` CLI available
- (Optional) ACM installed on the cluster

## Common Issues and Solutions

### Red Hat-Managed Certificate with Wrong Strategy

**Issue**: ACM configured with UseAutoDetectedCABundle for Red Hat-managed certificates
**Impact**: Cluster import failures with certificate validation errors
**Solution**: Configure UseSystemTruststore in KlusterletConfig

### Custom Certificate Without Root CA

**Issue**: Custom certificate chain doesn't include root CA
**Impact**: Certificate rotation with different intermediate CA will cause cluster failures
**Solution**: Add root CA to certificate chain, or use UseSystemTruststore for well-known CAs

### OpenShift-Managed to Custom Certificate Change

**Issue**: Planning to replace OpenShift-managed certificates after ACM installation
**Impact**: HIGH RISK - May cause managed clusters to go Unknown
**Solution**: Use the **assess-hub-cert-change** skill to evaluate risk and get mitigation guidance

## Features

- **Automated Detection** - Automatically identifies certificate type and ACM status
- **Certificate Chain Analysis** - Shows complete certificate chain with issuer relationships
- **Strategy Recommendation** - Suggests optimal ServerVerificationStrategy for your setup
- **Pre/Post Installation Support** - Tailored guidance based on ACM installation status
- **Compatibility Validation** - Verifies current configuration meets best practices

## Related Skills

- **assess-hub-cert-change** - Assess the risk of changing hub cluster certificates and get step-by-step guidance

## Best Practices

1. **Run this check before ACM installation** to verify certificate compatibility
2. **Include root CA in certificate chains** for private CAs to enable flexible rotation
3. **Use UseSystemTruststore for well-known CAs** (Let's Encrypt, DigiCert, etc.)
4. **Verify configuration after ACM installation** to catch any issues early
5. **Re-run after certificate changes** to ensure compatibility is maintained

## Troubleshooting

**"No kubeconfig specified"**
→ Set KUBECONFIG environment variable or use --kubeconfig parameter

**"oc command not found"**
→ Install OpenShift CLI (oc) and ensure it's in your PATH

**"Permission denied errors"**
→ Verify your kubeconfig has cluster-admin or sufficient permissions

**"Failed to retrieve certificate"**
→ Check cluster connectivity and that the API server is accessible

## Support

For detailed technical documentation, refer to:
- [ACM ServerVerificationStrategy Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.15/html-single/clusters/index#set-hub-kube-api-server)
- [OpenShift API Server Certificates](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/configuring-certificates#api-server-certificates)
