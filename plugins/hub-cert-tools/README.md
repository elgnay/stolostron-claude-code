# ACM Hub Certificate Tools

This plugin provides certificate tools for ACM (Advanced Cluster Management) hub clusters.

## Included Skills

### 1. Check Hub Cluster Certificate Configuration
- **Command**: `/check-hub-cert-config --kubeconfig <path>`
- **Purpose**: Check hub cluster kube-apiserver certificate configuration and its compatibility with ACM
- **Documentation**: [Full README](skills/check-hub-cert-config/README.md)

### 2. Assess Hub Certificate Change
- **Command**: `/assess-hub-cert-change --kubeconfig <path> --new-cert <path>`
- **Purpose**: Assess the risk and impact of changing hub cluster certificates on ACM clusters
- **Documentation**: [Full README](skills/assess-hub-cert-change/README.md)

## Installation

### From Marketplace

```bash
# Add the ACM skills marketplace
/plugin marketplace add https://github.com/stolostron/claude-code.git

# Install this hub certificate tools plugin
/plugin install hub-cert-tools@acm-skills-marketplace
```

### Manual Installation

Add to your Claude Code `settings.json`:
```json
{
  "skills": [
    "/path/to/claude-code/plugins/hub-cert-tools/skills/check-hub-cert-config",
    "/path/to/claude-code/plugins/hub-cert-tools/skills/assess-hub-cert-change"
  ]
}
```

## Use Cases

### Before ACM Installation
- ✅ Verify certificate compatibility with ACM
- ✅ Check if root CA is included in certificate chain
- ✅ Get recommended ServerVerificationStrategy configuration
- ✅ Identify potential issues before they occur

### After ACM Installation
- ✅ Validate current ServerVerificationStrategy configuration
- ✅ Troubleshoot managed cluster import failures
- ✅ Verify certificate chain completeness
- ✅ Plan certificate rotations safely

### During Certificate Changes
- ✅ Assess risk of certificate changes (LOW/MEDIUM/HIGH)
- ✅ Get step-by-step procedures for safe transitions
- ✅ Understand impact on managed clusters
- ✅ Identify offline clusters that won't receive updates

## Prerequisites

- **Claude Code CLI** - Latest version
- **OpenShift CLI (`oc`)** - For cluster access
- **OpenSSL** - For certificate analysis
- **Valid kubeconfig** - With cluster access permissions

## Quick Start

### Scenario 1: Planning ACM Installation

```bash
# Check if current certificates are compatible
export KUBECONFIG=/path/to/hub-kubeconfig
/check-hub-cert-config

# Review recommendations and proceed with ACM installation
```

### Scenario 2: Certificate Rotation

```bash
# Assess the planned certificate change
export KUBECONFIG=/path/to/hub-kubeconfig
/assess-hub-cert-change --new-cert /path/to/new-certificate.pem

# Follow the recommended procedure from the output
```

## Documentation

- [Usage Examples](examples/usage.md)
- [check-hub-cert-config README](skills/check-hub-cert-config/README.md)
- [assess-hub-cert-change README](skills/assess-hub-cert-change/README.md)

## Common Workflows

### Workflow 1: New Hub Cluster Setup
1. Check current certificate configuration
2. Verify ACM compatibility
3. Install ACM with appropriate ServerVerificationStrategy

### Workflow 2: Certificate Rotation
1. Check current configuration
2. Assess planned certificate change
3. Execute recommended procedure
4. Verify successful update

## Support

For issues or questions:
- GitHub Issues: https://github.com/stolostron/claude-code/issues
- Documentation: See individual skill READMEs

## License

See [LICENSE](../../LICENSE) for details.
