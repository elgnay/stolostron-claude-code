#!/bin/bash

# Hub Certificate Change Assessment
# Depends on check-hub-cert-config for shared libraries
# Usage: ./assess-hub-cert-change.sh --kubeconfig <path> --new-cert <path>

# Get script and skill directories
SCRIPT_DIR=`dirname "$0"`
SKILL_BASE_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"
PROJECT_ROOT="$( cd "${SKILL_BASE_DIR}/../.." && pwd )"

# Source shared libraries from check-hub-cert-config
CHECK_HUB_CERT_SKILL="${PROJECT_ROOT}/skills/check-hub-cert-config/scripts"
source "${CHECK_HUB_CERT_SKILL}/lib/common.sh"
source "${CHECK_HUB_CERT_SKILL}/lib/cert-analysis.sh"
source "${CHECK_HUB_CERT_SKILL}/lib/acm-detection.sh"

# Parse arguments
KUBECONFIG_PATH=""
NEW_CERT_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --new-cert) NEW_CERT_PATH="$2"; shift 2 ;;
        *)
            print_error "Unknown argument: $1"
            echo "Usage: $0 --kubeconfig <path> --new-cert <path>"
            exit 1
            ;;
    esac
done

# Validate arguments
if [ -z "$NEW_CERT_PATH" ]; then
    print_error "Missing required argument: --new-cert"
    echo "Usage: $0 --kubeconfig <path> --new-cert <path>"
    exit 1
fi

if [ -z "$KUBECONFIG_PATH" ]; then
    [ -n "$KUBECONFIG" ] && KUBECONFIG_PATH="$KUBECONFIG" || {
        print_error "No kubeconfig specified"
        exit 1
    }
fi

# Validate files exist
[ -f "$KUBECONFIG_PATH" ] || { print_error "Kubeconfig not found: $KUBECONFIG_PATH"; exit 1; }
[ -f "$NEW_CERT_PATH" ] || { print_error "Certificate not found: $NEW_CERT_PATH"; exit 1; }
grep -q "BEGIN CERTIFICATE" "$NEW_CERT_PATH" || { print_error "Invalid PEM certificate"; exit 1; }

# Set kubeconfig for all oc commands
export KUBECONFIG="$KUBECONFIG_PATH"

# Create temporary directory for certificate files and working directory
TEMP_DIR=`mktemp -d`
WORKDIR=`mktemp -d -t acm-cert-assessment`
trap "rm -rf $TEMP_DIR $WORKDIR" EXIT

#─────────────────────────────────────────────────────────────────────────────
# STEP 1: Analyze Current Certificate
#─────────────────────────────────────────────────────────────────────────────

# Analyze current certificate using shared library
analyze_current_certificate
if [ $? -ne 0 ]; then
    exit 1
fi

# Set API FQDN for use in procedures
API_FQDN="$API_HOSTNAME"

# Use full path for certificate file in procedures
CERT_FILENAME="$NEW_CERT_PATH"

print_success "Current certificate assessed"

# Check if current certificate is RedHat-Managed (not allowed to change)
if [ "$CERT_TYPE" = "RedHat-Managed" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    print_error "Certificate change not allowed"
    echo ""
    echo "Current certificate type: Red Hat-managed Certificate"
    echo ""
    echo "Red Hat-managed certificates (e.g., on ROSA, ARO clusters) are managed"
    echo "by Red Hat and cannot be replaced with custom certificates."
    echo ""
    echo "These certificates:"
    echo "  • Are automatically issued and renewed by Red Hat"
    echo "  • Use well-known CAs (e.g., Let's Encrypt)"
    echo "  • Are part of the managed service offering"
    echo ""
    echo "If you need custom certificates, consider using a self-managed"
    echo "OpenShift cluster instead of a Red Hat managed service."
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    exit 1
fi

#─────────────────────────────────────────────────────────────────────────────
# STEP 2: Detect ACM Configuration
#─────────────────────────────────────────────────────────────────────────────

# Detect ACM configuration using shared library
detect_acm_configuration
if [ $? -ne 0 ]; then
    print_error "Failed to detect ACM configuration"
    exit 1
fi

# Default to UseAutoDetectedCABundle if not set
[ -z "$SERVER_VERIFICATION_STRATEGY" ] && SERVER_VERIFICATION_STRATEGY="UseAutoDetectedCABundle"

# Convert strategy to readable format for display
case "$SERVER_VERIFICATION_STRATEGY" in
    UseAutoDetectedCABundle) STRATEGY_SHORT="Auto-Detected CA Bundle" ;;
    UseSystemTruststore) STRATEGY_SHORT="System Truststore" ;;
    UseCustomCABundles) STRATEGY_SHORT="Custom CA Bundles" ;;
    *) STRATEGY_SHORT="$SERVER_VERIFICATION_STRATEGY" ;;
esac

print_success "Strategy: $STRATEGY_SHORT"

#─────────────────────────────────────────────────────────────────────────────
# STEP 3: Analyze New Certificate
#─────────────────────────────────────────────────────────────────────────────

CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "$NEW_CERT_PATH")
[ $CERT_COUNT -eq 0 ] && { print_error "No certificates in file"; exit 1; }

cp "$NEW_CERT_PATH" "${WORKDIR}/new-fullchain.pem"
awk '/BEGIN CERTIFICATE/ {n++} n==1' "${WORKDIR}/new-fullchain.pem" > "${WORKDIR}/new-leaf.pem"

NEW_LEAF_SUBJECT=$(openssl x509 -in "${WORKDIR}/new-leaf.pem" -noout -subject)
NEW_LEAF_ISSUER=$(openssl x509 -in "${WORKDIR}/new-leaf.pem" -noout -issuer)

# Find new root CA
NEW_ROOT_CA_FOUND="no"
NEW_ROOT_CA=""
for i in $(seq 1 ${CERT_COUNT}); do
    SUBJ=$(awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/new-fullchain.pem" | openssl x509 -noout -subject)
    ISS=$(awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/new-fullchain.pem" | openssl x509 -noout -issuer)
    if [ "${SUBJ#subject=}" = "${ISS#issuer=}" ]; then
        NEW_ROOT_CA_FOUND="yes"
        NEW_ROOT_CA="$SUBJ"
        break
    fi
done
# If no root CA found, get issuer of last cert in chain (that's the root CA)
if [ -z "$NEW_ROOT_CA" ]; then
    LAST_CERT_ISSUER=$(awk "/BEGIN CERTIFICATE/ {n++} n==${CERT_COUNT}" "${WORKDIR}/new-fullchain.pem" | openssl x509 -noout -issuer 2>/dev/null)
    NEW_ROOT_CA="${LAST_CERT_ISSUER:-$NEW_LEAF_ISSUER}"
fi

print_success "New certificate assessed"

#─────────────────────────────────────────────────────────────────────────────
# STEP 3.5: Check Managed Cluster Status
#─────────────────────────────────────────────────────────────────────────────

# Only check managed clusters if ACM is installed
if [ "$MCH_FOUND" = true ]; then
    # Check if there are any managed clusters
    MANAGED_CLUSTERS=$(oc get managedclusters --no-headers 2>/dev/null)
    MC_EXIT_CODE=$?
    if [ $MC_EXIT_CODE -ne 0 ]; then
        print_error "Failed to query managed clusters"
        exit 1
    elif [ -z "$MANAGED_CLUSTERS" ]; then
        CLUSTERS_STATUS="No managed clusters found"
        UNAVAILABLE_CLUSTERS=""
    else
        # Get list of clusters that are not AVAILABLE
        UNAVAILABLE_CLUSTERS=$(oc get managedclusters -o json 2>/dev/null | \
            jq -r '.items[] | select((.status.conditions // [])[] | select(.type=="ManagedClusterConditionAvailable" and .status!="True")) | .metadata.name' 2>/dev/null)
        JQ_EXIT_CODE=$?
        if [ $JQ_EXIT_CODE -ne 0 ]; then
            print_error "Failed to evaluate managed cluster availability"
            exit 1
        fi

        TOTAL_CLUSTERS=$(echo "$MANAGED_CLUSTERS" | wc -l | tr -d ' ')
        if [ -z "$UNAVAILABLE_CLUSTERS" ]; then
            CLUSTERS_STATUS="All $TOTAL_CLUSTERS managed clusters are AVAILABLE"
        else
            UNAVAILABLE_COUNT=$(echo "$UNAVAILABLE_CLUSTERS" | wc -l | tr -d ' ')
            CLUSTERS_STATUS="$UNAVAILABLE_COUNT out of $TOTAL_CLUSTERS managed clusters are NOT AVAILABLE"
        fi
    fi
else
    # ACM not installed - skip managed cluster check
    CLUSTERS_STATUS="ACM not installed (no managed clusters)"
    UNAVAILABLE_CLUSTERS=""
fi

#─────────────────────────────────────────────────────────────────────────────
# STEP 4: Compare and Determine Scenario
#─────────────────────────────────────────────────────────────────────────────

# Normalize full DNs for comparison to avoid treating distinct CAs with same CN as identical
CURR_ROOT_NORM=$(normalize_full_dn "$CURRENT_ROOT_CA")
NEW_ROOT_NORM=$(normalize_full_dn "$NEW_ROOT_CA")
CURR_INT_NORM=$(normalize_full_dn "$CURRENT_LEAF_ISSUER")
NEW_INT_NORM=$(normalize_full_dn "$NEW_LEAF_ISSUER")

# Determine what changed
[ "$CURR_ROOT_NORM" = "$NEW_ROOT_NORM" ] && ROOT_CHANGED="no" || ROOT_CHANGED="yes"
[ "$CURR_INT_NORM" = "$NEW_INT_NORM" ] && INT_CHANGED="no" || INT_CHANGED="yes"

# Determine scenario and procedure
if [ "$ROOT_CHANGED" = "no" ] && [ "$INT_CHANGED" = "no" ]; then
    SCENARIO="1"; SCENARIO_NAME="Certificate Renewal"
    PROCEDURE="A"; PROCEDURE_NAME="Simple Certificate Update"
    RISK="LOW"
elif [ "$ROOT_CHANGED" = "no" ] && [ "$INT_CHANGED" = "yes" ]; then
    SCENARIO="2"; SCENARIO_NAME="New Intermediate CA (same root)"
    case "$SERVER_VERIFICATION_STRATEGY" in
        UseAutoDetectedCABundle)
            [ "$CURRENT_ROOT_INCLUDED" = "yes" ] && PROCEDURE="A" || PROCEDURE="B"
            [ "$PROCEDURE" = "A" ] && RISK="LOW" || RISK="MEDIUM"
            ;;
        UseSystemTruststore) PROCEDURE="A"; RISK="LOW" ;;
        *) PROCEDURE="B"; RISK="MEDIUM" ;;  # Default to B (safer option)
    esac
    [ "$PROCEDURE" = "A" ] && PROCEDURE_NAME="Simple Certificate Update"
    [ "$PROCEDURE" = "B" ] && PROCEDURE_NAME="Add Root CA and Update"
else
    SCENARIO="3"; SCENARIO_NAME="New Root CA"
    RISK="HIGH"
    case "$SERVER_VERIFICATION_STRATEGY" in
        UseAutoDetectedCABundle) PROCEDURE="C"; PROCEDURE_NAME="3-Phase Update (Auto-Detection)" ;;
        UseCustomCABundles) PROCEDURE="D"; PROCEDURE_NAME="3-Phase Update (Custom Bundles)" ;;
        *) PROCEDURE="C"; PROCEDURE_NAME="3-Phase Update (Auto-Detection)" ;;
    esac
fi

# If ACM is not installed, override with simple OCP procedure
if [ "$MCH_FOUND" != true ]; then
    PROCEDURE="OCP"
    PROCEDURE_NAME="Standard OCP Certificate Update"
    # No managed clusters means low risk (only brief API server restart)
    RISK="LOW"
fi

#─────────────────────────────────────────────────────────────────────────────
# STEP 5: Generate Report
#─────────────────────────────────────────────────────────────────────────────

echo ""
print_divider
echo -e "${CYAN}   Hub Certificate Change Assessment${NC}"
print_divider

# Section 1: Current Configuration
print_header "Current Certificate Configuration"
echo "Certificate Type: $CERT_TYPE"
echo "Subject: ${CURRENT_LEAF_SUBJECT#subject=}"
echo "Issuer: ${CURRENT_LEAF_ISSUER#issuer=}"
echo "Root CA: ${CURRENT_ROOT_CA#subject=}$([ "$CURRENT_ROOT_INCLUDED" = "yes" ] && echo " (included)" || echo " (not included)")"

# Section 2: ACM Configuration
print_header "ACM Configuration"
case "$SERVER_VERIFICATION_STRATEGY" in
    UseAutoDetectedCABundle) STRATEGY_DISPLAY="Auto-Detected CA Bundle" ;;
    UseSystemTruststore) STRATEGY_DISPLAY="System Truststore" ;;
    UseCustomCABundles) STRATEGY_DISPLAY="Custom CA Bundles" ;;
    *) STRATEGY_DISPLAY="$SERVER_VERIFICATION_STRATEGY" ;;
esac
echo "Verification Strategy: $STRATEGY_DISPLAY"

# Section 2.5: Managed Cluster Status
print_header "Managed Cluster Status"
echo "$CLUSTERS_STATUS"
if [ -n "$UNAVAILABLE_CLUSTERS" ]; then
    echo ""
    echo -e "${RED}⚠️  WARNING: The following clusters are NOT AVAILABLE:${NC}"
    echo "$UNAVAILABLE_CLUSTERS" | while read cluster; do
        echo "  • $cluster"
    done
    echo ""
    echo -e "${YELLOW}Certificate changes (especially root CA changes) may fail for offline clusters.${NC}"
    echo -e "${YELLOW}Offline clusters cannot receive new CA certificates and will lose connectivity.${NC}"
fi

# Section 3: New Certificate
print_header "Planned Certificate Change"
echo "New Subject: ${NEW_LEAF_SUBJECT#subject=}"
echo "New Issuer: ${NEW_LEAF_ISSUER#issuer=}"
echo "New Root CA: ${NEW_ROOT_CA#*=}$([ "$NEW_ROOT_CA_FOUND" = "yes" ] && echo " (included)" || echo " (not included)")"

# Section 4: Change Assessment
print_header "Change Assessment"
echo "What's changing:"
[ "$ROOT_CHANGED" = "yes" ] && echo -e "  ${RED}•${NC} Root CA: Changing" || echo -e "  ${GREEN}•${NC} Root CA: No change"
[ "$INT_CHANGED" = "yes" ] && echo -e "  ${YELLOW}•${NC} Intermediate CA: Changing" || echo -e "  ${GREEN}•${NC} Intermediate CA: No change"

# Section 5: Risk Assessment
print_header "Risk Assessment"
case "$RISK" in
    LOW) RISK_EMOJI="🟢" ;;
    MEDIUM) RISK_EMOJI="🟡" ;;
    HIGH) RISK_EMOJI="🔴" ;;
    *) RISK_EMOJI="⚠️" ;;
esac
echo "Risk Level: $RISK_EMOJI $RISK"
echo ""
case "$RISK" in
    LOW) echo "No special preparation needed. Minimal disruption during API restart." ;;
    MEDIUM) echo "Preparation required before certificate update. Follow procedure carefully." ;;
    HIGH) echo "⚠️  WARNING: Do NOT update certificate directly!"
         echo "   Managed clusters may go Unknown and lose connection to hub."
         echo "   Must follow 3-phase procedure to prevent disruption." ;;
esac

# Additional warning if there are unavailable clusters
if [ -n "$UNAVAILABLE_CLUSTERS" ]; then
    echo ""
    echo -e "${RED}⚠️  CRITICAL: Unavailable managed clusters detected!${NC}"
    echo "   Certificate changes cannot propagate to offline clusters."
    echo "   Recommendation: Bring all clusters online before proceeding, or accept that"
    echo "   offline clusters will lose connectivity and require manual remediation."
fi

# Section 6: Recommended Procedure
print_header "Recommended Procedure"
echo "Procedure: $PROCEDURE_NAME"
echo ""

# Embed procedure instructions
case "$PROCEDURE" in
    A)
        cat <<PROCEDURE
Step 1: Create the certificate secret
  oc create secret tls api-server-cert --cert=$CERT_FILENAME --key=/path/to/new-key.pem -n openshift-config

Step 2: Update APIServer configuration
  oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["$API_FQDN"],"servingCertificate":{"name":"api-server-cert"}}]}}}'

Step 3: Verify managed clusters remain AVAILABLE
  # Watch for 15 minutes and ensure all clusters show AVAILABLE=True
  oc get managedclusters -w
PROCEDURE
        ;;
    B)
        cat <<PROCEDURE
Step 1: Extract root CA from new certificate chain
  # If root CA is the last cert in your chain file:
  awk '/BEGIN CERTIFICATE/ {n++} n==<last-position>' $CERT_FILENAME > root-ca-bundle.crt

  # Verify it's self-signed (subject == issuer):
  openssl x509 -in root-ca-bundle.crt -noout -subject -issuer

Step 2: Create ConfigMap with root CA
  oc create configmap root-ca-bundle --from-file=ca.crt=root-ca-bundle.crt -n multicluster-engine

Step 3: Add root CA to KlusterletConfig
  # Check if KlusterletConfig exists:
  oc get klusterletconfig global

  # If it exists, patch it to add the new root CA:
  oc patch klusterletconfig global --type=merge -p '{"spec":{"hubKubeAPIServerConfig":{"trustedCABundles":[{"name":"root-ca","caBundle":{"name":"root-ca-bundle","namespace":"multicluster-engine"}}]}}}'

  # If it does not exist, create it with the new root CA:
  oc create -f - <<EOF
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    trustedCABundles:
    - name: root-ca
      caBundle:
        name: root-ca-bundle
        namespace: multicluster-engine
EOF

Step 4: Wait for propagation (5 minutes)
  # Watch klusterlet pods restart on managed clusters:
  oc get pods -n open-cluster-management-agent -w

Step 5: Create the certificate secret
  oc create secret tls api-server-cert --cert=$CERT_FILENAME --key=/path/to/new-key.pem -n openshift-config

Step 6: Update APIServer configuration
  oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["$API_FQDN"],"servingCertificate":{"name":"api-server-cert"}}]}}}'

Step 7: Verify managed clusters remain AVAILABLE
  # Watch for 15 minutes and ensure all clusters show AVAILABLE=True
  oc get managedclusters -w
PROCEDURE
        ;;
    C)
        cat <<PROCEDURE
═══ PHASE 1: Add New CA to Trusted Bundles ═══

Step 1: Extract root + intermediate CAs (exclude leaf certificate)
  # Extract all certs except the first one (leaf):
  awk '/BEGIN CERTIFICATE/ {n++} n>=2' $CERT_FILENAME > new-ca-bundle.crt

  # Verify the bundle contains root + intermediates:
  grep -c "BEGIN CERTIFICATE" new-ca-bundle.crt

Step 2: Create ConfigMap
  oc create configmap new-root-ca-bundle --from-file=ca.crt=new-ca-bundle.crt -n multicluster-engine

Step 3: Add to KlusterletConfig
  # Check if KlusterletConfig exists:
  oc get klusterletconfig global

  # If it exists, patch it to add the new root CA:
  oc patch klusterletconfig global --type=merge -p '{"spec":{"hubKubeAPIServerConfig":{"trustedCABundles":[{"name":"new-root-ca","caBundle":{"name":"new-root-ca-bundle","namespace":"multicluster-engine"}}]}}}'

  # If it does not exist, create it with the new root CA:
  oc create -f - <<EOF
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    trustedCABundles:
    - name: new-root-ca
      caBundle:
        name: new-root-ca-bundle
        namespace: multicluster-engine
EOF

Step 4: Wait for propagation (5 minutes)

═══ PHASE 2: Update Certificate ═══

Step 5: Create certificate secret
  oc create secret tls api-server-cert --cert=$CERT_FILENAME --key=/path/to/new-key.pem -n openshift-config

Step 6: Update APIServer
  oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["$API_FQDN"],"servingCertificate":{"name":"api-server-cert"}}]}}}'

Step 7: Verify managed clusters
  # Watch for 15 minutes, all should remain AVAILABLE=True
  oc get managedclusters -w

═══ PHASE 3: Remove Temporary CA Configuration ═══

Step 8: Remove the temporary trustedCABundles configuration
  If you had NO pre-existing trustedCABundles entries, remove the entire section:
  oc patch klusterletconfig global --type=json -p '[{"op": "remove", "path": "/spec/hubKubeAPIServerConfig/trustedCABundles"}]'

  If you had pre-existing trustedCABundles entries, manually edit to remove only the temporary entry:
  oc edit klusterletconfig global

Step 9: Monitor propagation and verify managed clusters
  # Watch for 15 minutes during propagation, all should remain AVAILABLE=True
  oc get managedclusters -w

Step 10: Delete temporary ConfigMap
  oc delete configmap new-root-ca-bundle -n multicluster-engine
PROCEDURE
        ;;
    D)
        cat <<PROCEDURE
═══ PHASE 1: Add New CA Alongside Existing ═══

Step 1: Extract root + intermediate CAs (exclude leaf certificate)
  # Extract all certs except the first one (leaf):
  awk '/BEGIN CERTIFICATE/ {n++} n>=2' $CERT_FILENAME > new-ca-bundle.crt

Step 2: Create ConfigMap
  oc create configmap new-root-ca-bundle --from-file=ca.crt=new-ca-bundle.crt -n multicluster-engine

Step 3: Get current trustedCABundles
  oc get klusterletconfig global -o yaml
  # Note existing entries in spec.hubKubeAPIServerConfig.trustedCABundles

Step 4: Add new CA to existing list (keep old entries!)
  # Check if KlusterletConfig exists:
  oc get klusterletconfig global

  # If it exists, patch it to add the new root CA to existing list (example):
  oc patch klusterletconfig global --type=merge -p '{"spec":{"hubKubeAPIServerConfig":{"serverVerificationStrategy":"UseCustomCABundles","trustedCABundles":[{"name":"old-ca","caBundle":{"name":"old-ca-bundle","namespace":"multicluster-engine"}},{"name":"new-root-ca","caBundle":{"name":"new-root-ca-bundle","namespace":"multicluster-engine"}}]}}}'

  # If it does not exist, create with both CAs (adjust old-ca-bundle based on your setup):
  oc create -f - <<EOF
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    serverVerificationStrategy: UseCustomCABundles
    trustedCABundles:
    - name: old-ca
      caBundle:
        name: old-ca-bundle
        namespace: multicluster-engine
    - name: new-root-ca
      caBundle:
        name: new-root-ca-bundle
        namespace: multicluster-engine
EOF

Step 5: Wait for propagation (5 minutes)

═══ PHASE 2: Update Certificate ═══

Step 6: Create certificate secret
  oc create secret tls api-server-cert --cert=$CERT_FILENAME --key=/path/to/new-key.pem -n openshift-config

Step 7: Update APIServer
  oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["$API_FQDN"],"servingCertificate":{"name":"api-server-cert"}}]}}}'

Step 8: Verify managed clusters
  # Watch for 15 minutes, all should remain AVAILABLE=True
  oc get managedclusters -w

═══ PHASE 3: Remove Old CA ═══

Step 9: Update KlusterletConfig - keep only new CA
  oc patch klusterletconfig global --type=merge -p '{"spec":{"hubKubeAPIServerConfig":{"serverVerificationStrategy":"UseCustomCABundles","trustedCABundles":[{"name":"new-root-ca","caBundle":{"name":"new-root-ca-bundle","namespace":"multicluster-engine"}}]}}}'

Step 10: Monitor propagation and verify managed clusters
  # Watch for 15 minutes during propagation, all should remain AVAILABLE=True
  oc get managedclusters -w

Step 11: Delete old ConfigMap (optional)
  oc delete configmap old-ca-bundle -n multicluster-engine
PROCEDURE
        ;;
    OCP)
        cat <<PROCEDURE
ACM is not installed on this cluster.

Follow the standard OpenShift documentation to update the kube-apiserver
serving certificate:

  https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/configuring-certificates#add-named-certificates-for-the-api-server_configuring-certificates

Important Notes:
  • Ensure the certificate is valid for the API server FQDN: $API_FQDN
  • The certificate chain should be complete (leaf + intermediates + root CA)
  • If you plan to install ACM later, run /check-hub-cert-config after
    updating the certificate to verify ACM compatibility
PROCEDURE
        ;;
esac

echo ""
print_divider
echo ""
print_success "Assessment complete"
[ "$RISK" = "HIGH" ] && print_warning "HIGH RISK: Read complete procedure before starting!"
echo ""
