#!/bin/bash

# ACM Certificate Configuration Check - Self-Contained Script
# Checks certificate configuration, ACM status, and provides recommendations
# Usage: ./check-hub-cert-config.sh [--kubeconfig <path>]
#        If --kubeconfig is not specified, uses KUBECONFIG environment variable

# Get script directory
SCRIPT_DIR=`dirname "$0"`

# Source shared libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/cert-analysis.sh"
source "${SCRIPT_DIR}/lib/acm-detection.sh"

# Parse named arguments
KUBECONFIG_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        *)
            print_error "Unknown argument: $1"
            echo ""
            echo "Usage: $0 [--kubeconfig <path>]"
            exit 1
            ;;
    esac
done

# Determine kubeconfig path
if [ -z "$KUBECONFIG_PATH" ]; then
    if [ -n "$KUBECONFIG" ]; then
        KUBECONFIG_PATH="$KUBECONFIG"
    else
        print_error "No kubeconfig specified"
        echo ""
        echo "Please provide kubeconfig in one of the following ways:"
        echo "  1. Use --kubeconfig parameter: $0 --kubeconfig <path>"
        echo "  2. Set KUBECONFIG environment variable: export KUBECONFIG=<path>"
        exit 1
    fi
fi

# Validate kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    print_error "Kubeconfig file not found: $KUBECONFIG_PATH"
    exit 1
fi

# Create temporary directory for certificate files
TEMP_DIR=`mktemp -d`
trap "rm -rf $TEMP_DIR" EXIT

echo "Hub Cluster Certificate Configuration Check"
echo ""

# Set kubeconfig for all oc commands
export KUBECONFIG="$KUBECONFIG_PATH"

# Get cluster information
CURRENT_USER=`oc whoami 2>/dev/null`
if [ -z "$CURRENT_USER" ]; then
    CURRENT_USER="Unknown"
fi

OCP_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}' 2>/dev/null`
if [ -z "$OCP_ENDPOINT" ]; then
    OCP_ENDPOINT="Unknown"
fi

OCP_VERSION=`oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null`
if [ -z "$OCP_VERSION" ]; then
    OCP_VERSION="Unknown"
fi

# Step 1: Display cluster information
print_header "Step 1: Cluster Information"
echo ""
echo "Kubeconfig:    $KUBECONFIG_PATH"
echo "API Endpoint:  $OCP_ENDPOINT"
echo "OCP Version:   $OCP_VERSION"
echo "Current User:  $CURRENT_USER"
echo ""

# Step 2: Cluster Kube APIServer Certificates
print_header "Step 2: Cluster Kube APIServer Certificates"
echo ""

# Analyze current certificate using shared library
analyze_current_certificate
if [ $? -ne 0 ]; then
    exit 1
fi

# Get certificate details for display
CERT_SUBJECT=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -subject | sed 's/subject=//'`
CERT_ISSUER=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -issuer | sed 's/issuer=//'`
CERT_VALIDITY=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -enddate | sed 's/notAfter=//'`

# Save the intermediate CA before it gets overwritten
INTERMEDIATE_CA="$CERT_ISSUER"

# Set display name based on CERT_TYPE
case "$CERT_TYPE" in
    "OpenShift-Managed") CERT_TYPE_DISPLAY="OpenShift-Managed Certificate" ;;
    "RedHat-Managed") CERT_TYPE_DISPLAY="Red Hat-managed Certificate" ;;
    "Custom-WellKnown") CERT_TYPE_DISPLAY="Custom Certificate (Well-Known CA)" ;;
    "Custom-SelfSigned") CERT_TYPE_DISPLAY="Custom Certificate (Private CA)" ;;
    *) CERT_TYPE_DISPLAY="$CERT_TYPE" ;;
esac

# Convert root included flag for display
[ "$CURRENT_ROOT_INCLUDED" = "yes" ] && ROOT_CA_INCLUDED="Yes" || ROOT_CA_INCLUDED="No"

# Display certificate details
echo "Certificate Type: $CERT_TYPE_DISPLAY"
if [ -n "$CERT_SUBJECT" ]; then
    echo "Subject:          $CERT_SUBJECT"
fi
if [ -n "$CERT_ISSUER" ]; then
    echo "Issuer:           $CERT_ISSUER"
fi
if [ -n "$CERT_VALIDITY" ]; then
    echo "Valid Until:      $CERT_VALIDITY"
fi
echo "Root CA Included: $ROOT_CA_INCLUDED"

# Display certificate chain
echo ""
echo "Certificate Chain:"

# Get serving certificate info
SERVING_SUBJECT=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -subject 2>/dev/null | sed 's/subject=//'`
SERVING_ISSUER=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -issuer 2>/dev/null | sed 's/issuer=//'`

if [ -n "$SERVING_SUBJECT" ] && [ -f "${TEMP_DIR}/ca-bundle.crt" ]; then
    # Build the actual signing chain by following issuer links
    CHAIN_NUM=1
    CURRENT_ISSUER="$SERVING_ISSUER"

    # Display serving certificate first
    echo "  [$CHAIN_NUM] Subject: $SERVING_SUBJECT"
    echo "      Issuer:  $SERVING_ISSUER"

    # Split CA bundle into individual certificates
    # Use awk to split certificates (more portable than csplit)
    awk '/-----BEGIN CERTIFICATE-----/{x="'"${TEMP_DIR}"'/ca-cert-"++i".pem";}{print > x}' "${TEMP_DIR}/ca-bundle.crt"

    # Follow the chain through CA bundle
    while [ -n "$CURRENT_ISSUER" ]; do
        CHAIN_NUM=$((CHAIN_NUM + 1))
        CERT_FOUND=""

        # Find certificate in CA bundle where subject matches current issuer
        for cert_file in "${TEMP_DIR}"/ca-cert-*.pem; do
            if [ -f "$cert_file" ] && grep -q "BEGIN CERTIFICATE" "$cert_file"; then
                CERT_SUBJ=`openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//'`

                if [ "$CERT_SUBJ" = "$CURRENT_ISSUER" ]; then
                    CERT_ISS=`openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/issuer=//'`
                    CERT_FOUND="true"

                    echo ""
                    echo "  [$CHAIN_NUM] Subject: $CERT_SUBJ"
                    echo "      Issuer:  $CERT_ISS"

                    # Check if this is a self-signed root CA
                    if [ "$CERT_SUBJ" = "$CERT_ISS" ]; then
                        break 2
                    fi

                    CURRENT_ISSUER="$CERT_ISS"
                    break
                fi
            fi
        done

        if [ -z "$CERT_FOUND" ]; then
            # Issuer not found in CA bundle
            echo ""
            echo "  [$CHAIN_NUM] Subject: $CURRENT_ISSUER (Not Included)"
            echo "      Issuer:  $CURRENT_ISSUER"
            break
        fi
    done
else
    echo "  [1] Subject: $SERVING_SUBJECT"
    echo "      Issuer:  $SERVING_ISSUER"
fi

echo ""

# Step 3: ACM Status
print_header "Step 3: ACM Status"
echo ""

# Detect ACM configuration using shared library
detect_acm_configuration
if [ $? -ne 0 ]; then
    print_error "ACM detection failed; cannot continue analysis"
    exit 1
fi

# Output ACM status
if [ "$MCH_FOUND" = true ]; then
    print_success "ACM Status: INSTALLED"
    echo "  Version:   $MCH_VERSION"
    echo "  Namespace: $MCH_NAMESPACE"
    echo "  Name:      $MCH_NAME"
    echo "  Status:    $MCH_STATUS"
    ACM_STATUS="INSTALLED"
elif [ "$OPERATOR_FOUND" = true ]; then
    print_info "ACM Status: OPERATOR ONLY"
    ACM_STATUS="OPERATOR_ONLY"
else
    print_success "ACM Status: NOT INSTALLED"
    ACM_STATUS="NOT_INSTALLED"
fi
echo ""

# Step 4: ACM Certificate Configuration Check
print_header "Step 4: ACM Certificate Configuration Check"
echo ""
echo "Recommended ServerVerificationStrategy:"
echo ""

# Determine recommended strategy based on certificate type
RECOMMENDED_STRATEGY=""
STRATEGY_NOTE=""
STRATEGY_NOTE2=""

case "$CERT_TYPE" in
    "OpenShift-Managed")
        RECOMMENDED_STRATEGY="UseAutoDetectedCABundle"
        STRATEGY_NOTE="OpenShift-managed certificates work best with auto-detection"
        ;;
    "RedHat-Managed")
        RECOMMENDED_STRATEGY="UseSystemTruststore"
        STRATEGY_NOTE="RedHat-managed certificates use well-known CAs trusted by system stores"
        ;;
    "Custom-WellKnown")
        if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle or UseSystemTruststore"
            STRATEGY_NOTE="Option 1: UseAutoDetectedCABundle (full CA chain is included)"
            STRATEGY_NOTE2="Option 2: UseSystemTruststore (well-known CA is trusted by system)"
        else
            RECOMMENDED_STRATEGY="UseSystemTruststore"
            STRATEGY_NOTE="UseSystemTruststore is recommended when root CA is not in the chain"
            STRATEGY_NOTE2="Alternative: Add root CA to chain, then use UseAutoDetectedCABundle"
        fi
        ;;
    "Custom-SelfSigned")
        if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle"
            STRATEGY_NOTE="Private CA certificates require auto-detection with full CA chain"
        else
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle (after adding root CA)"
            STRATEGY_NOTE="⚠️  ACM may work with current certificates but has rotation risks"
            STRATEGY_NOTE2="Certificate rotation with different intermediate CA will cause managed clusters to enter unknown state"
        fi
        ;;
    *)
        RECOMMENDED_STRATEGY="Unknown"
        STRATEGY_NOTE="Unable to determine recommended strategy"
        ;;
esac

echo "  Recommended: $RECOMMENDED_STRATEGY"
if [ -n "$STRATEGY_NOTE" ]; then
    echo "  • $STRATEGY_NOTE"
fi
if [ -n "$STRATEGY_NOTE2" ]; then
    echo "  • $STRATEGY_NOTE2"
fi

# Show current configuration if ACM is installed
if [ "$ACM_STATUS" = "INSTALLED" ] && [ -n "$SERVER_VERIFICATION_STRATEGY" ]; then
    echo ""
    echo "  Current: $SERVER_VERIFICATION_STRATEGY"

    if echo "$RECOMMENDED_STRATEGY" | grep -q "$SERVER_VERIFICATION_STRATEGY"; then
        echo "  Status: ✓ Matches recommendation"
    else
        echo "  Status: ⚠️  Does not match recommendation"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 5: Configuration Summary and Recommendations
print_header "Step 5: Configuration Summary"
echo ""

echo "OCP API Endpoint: $OCP_ENDPOINT"
echo "OCP Version: $OCP_VERSION"
echo "Certificate Type: $CERT_TYPE"
echo "Root CA Included: $ROOT_CA_INCLUDED"

if [ "$ACM_STATUS" = "INSTALLED" ]; then
    echo "ACM: Installed (Version $MCH_VERSION)"
    if [ -n "$SERVER_VERIFICATION_STRATEGY" ]; then
        echo "ServerVerificationStrategy: $SERVER_VERIFICATION_STRATEGY"
    fi
else
    if [ "$ACM_STATUS" = "OPERATOR_ONLY" ]; then
        echo "ACM: Operator installed, MultiClusterHub not deployed"
    else
        echo "ACM: Not installed"
    fi
fi
echo ""

# Provide recommendations based on ACM status and cert type
if [ "$ACM_STATUS" = "INSTALLED" ]; then
    case "$CERT_TYPE" in
        "OpenShift-Managed")
            print_success "Configuration: Compatible"
            echo ""
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
                    echo "Root CA is included in certificate chain"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                else
                    echo "Root CA is NOT included in the served certificate chain"
                    echo "  • Root CA is available in the kube-apiserver-server-ca ConfigMap"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                fi
            else
                echo "Current configuration is working correctly"
                echo "  • No additional configuration required"
            fi
            echo ""
            echo "Important considerations:"
            echo "  • ⚠️  Replacing kube-apiserver certificate with Custom certificate after ACM installation may cause managed clusters to enter unknown state"
            echo "  • If you really need to replace the certificate after ACM installation, use the assess-hub-cert-change skill to evaluate the risk and get mitigation guidance"
            echo ""
            ;;
        "RedHat-Managed")
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseSystemTruststore" ]; then
                print_success "Configuration: Compatible"
                echo ""
                echo "UseSystemTruststore is configured correctly"
                echo "  • RedHat-managed certificates use well-known CAs (e.g., Let's Encrypt)"
                echo "  • Well-known CAs are already trusted by the system trust store"
                echo "  • No additional configuration required"
            else
                print_info "Configuration Issue"
                echo ""
                echo "Current configuration will cause cluster import failures"
                echo "  • UseAutoDetectedCABundle cannot detect well-known CA roots"
                echo "  • Cluster import will fail with certificate validation errors"
                echo ""
                echo "Required action:"
                echo "  • Configure UseSystemTruststore as the KubeAPIServer verification strategy in the global KlusterletConfig"
            fi
            ;;
        "Custom-WellKnown")
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                if [ "$ROOT_CA_INCLUDED" != "Yes" ]; then
                    print_info "Configuration Notes"
                    echo ""
                    echo "ACM may work with current certificates but has rotation limitations"
                    echo "  • Certificate rotation MUST use the same intermediate CA ($INTERMEDIATE_CA)"
                    echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
                    echo ""
                    echo "Recommended actions (choose one):"
                    echo "  • Option 1: Add root CA to the certificate chain (enables flexible rotation, continue using UseAutoDetectedCABundle)"
                    echo "  • Option 2: Configure UseSystemTruststore as the KubeAPIServer verification strategy (well-known CAs are already in system trust store)"
                else
                    print_success "Configuration: Compatible"
                    echo ""
                    echo "Root CA is included in certificate chain"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                fi
            else
                print_success "Configuration: Compatible"
                echo ""
                echo "Current configuration is working correctly"
                echo "  • No additional configuration required"
            fi
            ;;
        "Custom-SelfSigned")
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                if [ "$ROOT_CA_INCLUDED" != "Yes" ]; then
                    print_info "Configuration Notes"
                    echo ""
                    echo "ACM may work with current certificates but has rotation limitations"
                    echo "  • Certificate rotation MUST use the same intermediate CA ($INTERMEDIATE_CA)"
                    echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
                    echo ""
                    echo "Recommended actions:"
                    echo "  1. Add root CA to the certificate chain to enable flexible certificate rotation"
                    echo "  2. Re-run this skill to verify the configuration after adding root CA"
                else
                    print_success "Configuration: Compatible"
                    echo ""
                    echo "Root CA is included in certificate chain"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                fi
            else
                print_success "Configuration: Compatible"
                echo ""
                echo "Current configuration is working correctly"
                echo "  • No additional configuration required"
            fi
            ;;
        *)
            print_error "Unknown certificate type - manual verification required"
            ;;
    esac
else
    case "$CERT_TYPE" in
        "OpenShift-Managed")
            print_success "Safe to install ACM"
            echo ""
            echo "Recommended actions (choose one):"
            echo ""
            echo "  Option 1: Install ACM with current OpenShift-Managed certificates"
            echo "    • Safe to proceed with installation"
            echo "    • No additional configuration required"
            echo "    • ⚠️  Replacing kube-apiserver certificate with Custom certificate after ACM installation may cause managed clusters to enter unknown state"
            echo "    • If you really need to replace certificates later, use assess-hub-cert-change skill first"
            echo ""
            echo "  Option 2: Configure Custom certificates BEFORE installing ACM"
            echo "    • Configure Custom kube-apiserver certificates first"
            echo "    • Then install ACM with Custom certificate configuration"
            echo "    • This avoids the risk of certificate type change after installation"
            ;;
        "RedHat-Managed")
            print_success "Safe to install ACM"
            echo ""
            echo "Next steps:"
            echo "  1. Proceed with ACM installation"
            echo "  2. Configure UseSystemTruststore as the KubeAPIServer verification strategy in the global KlusterletConfig after installation"
            echo ""
            echo "Note:"
            echo "  • Well-known CAs (e.g., Let's Encrypt) are automatically trusted by system trust stores"
            echo "  • No additional configuration required beyond step 2"
            ;;
        "Custom-WellKnown")
            if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
                print_success "Safe to install ACM"
                echo ""
                echo "Root CA is included in certificate chain"
                echo ""
                echo "Next steps:"
                echo "  1. Proceed with ACM installation"
                echo "  2. (Optional) Configure UseSystemTruststore as the KubeAPIServer verification strategy in the global KlusterletConfig to simplify certificate management"
                echo ""
                echo "Note:"
                echo "  • Well-known CAs (e.g., Let's Encrypt) are already trusted by system trust stores"
                echo "  • No required configuration"
            else
                print_info "ACM may work initially but has certificate rotation risk"
                echo ""
                echo "Root CA is NOT included in certificate chain"
                echo ""
                echo "Recommended actions (choose one):"
                echo ""
                echo "  Option 1: Add root CA to certificate chain"
                echo "    • Add the root CA certificate to the certificate chain"
                echo "    • Then proceed with ACM installation"
                echo "    • No additional ACM configuration needed"
                echo ""
                echo "  Option 2: Use system trust store"
                echo "    • Proceed with ACM installation as-is"
                echo "    • Configure UseSystemTruststore as the KubeAPIServer verification strategy in the global KlusterletConfig after installation"
                echo "    • System trust store already contains well-known CA root certificates"
                echo ""
                echo "Risk if neither option is implemented:"
                echo "  • Certificate rotation with different intermediate CA will cause managed clusters to enter unknown state"
                echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
            fi
            ;;
        "Custom-SelfSigned")
            if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
                print_success "Safe to install ACM"
                echo ""
                echo "Root CA is included in certificate chain"
                echo ""
                echo "Next steps:"
                echo "  1. Proceed with ACM installation"
                echo ""
                echo "Note:"
                echo "  • ACM will automatically detect the CA bundle and distribute it to managed clusters"
                echo "  • No additional configuration required"
            else
                print_info "ACM may work initially but has certificate rotation risk"
                echo ""
                echo "Root CA is NOT included in certificate chain"
                echo ""
                echo "Recommended actions:"
                echo "  1. Add the root CA certificate to the certificate chain before installing ACM"
                echo "  2. Re-run this analysis to confirm the complete chain is included"
                echo ""
                echo "Risk if not addressed:"
                echo "  • Certificate rotation with different intermediate CA will cause managed clusters to enter unknown state"
                echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
            fi
            ;;
        *)
            print_error "Unknown certificate type - manual verification required"
            ;;
    esac
fi

echo ""
