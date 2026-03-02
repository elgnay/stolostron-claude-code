#!/bin/bash

# Certificate Analysis Library
# Shared functions for analyzing cluster certificates

# Requires: TEMP_DIR to be set and KUBECONFIG to be exported
# Requires: lib/common.sh to be sourced for print functions

#──────────────────────────────────────────────────────────────────────────────
# analyze_current_certificate
# Analyzes the current kube-apiserver certificate from the cluster
# Sets global variables:
#   - OCP_ENDPOINT
#   - API_HOSTNAME
#   - API_PORT
#   - CERT_TYPE (OpenShift-Managed, RedHat-Managed, Custom-WellKnown, Custom-SelfSigned)
#   - CURRENT_LEAF_SUBJECT
#   - CURRENT_LEAF_ISSUER
#   - CURRENT_ROOT_CA
#   - CURRENT_ROOT_INCLUDED (yes/no)
#──────────────────────────────────────────────────────────────────────────────
analyze_current_certificate() {
    # Get cluster information
    OCP_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}' 2>/dev/null`
    if [ -z "$OCP_ENDPOINT" ]; then
        print_error "Failed to get cluster API endpoint"
        return 1
    fi

    # Extract API hostname and port
    API_HOSTNAME=`echo "$OCP_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'`
    API_PORT=`echo "$OCP_ENDPOINT" | sed 's|.*:||'`

    # Retrieve certificate chain using openssl
    echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null > "${TEMP_DIR}/openssl_output.txt"
    if [ $? -ne 0 ]; then
        print_error "Failed to retrieve certificate chain"
        return 1
    fi

    # Extract certificates
    sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${TEMP_DIR}/openssl_output.txt" > "${TEMP_DIR}/fullchain.pem"
    awk '/BEGIN CERTIFICATE/ {n++} n==1' "${TEMP_DIR}/fullchain.pem" > "${TEMP_DIR}/serving-cert.pem"

    # Determine certificate type
    ISSUER=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -issuer`

    # Check if issuer is kube-apiserver-lb-signer
    if echo "$ISSUER" | grep -q "CN=kube-apiserver-lb-signer"; then
        IS_KUBE_SIGNER="true"
    else
        IS_KUBE_SIGNER="false"
    fi

    # Check if this is a Red Hat managed domain (check FIRST before checking custom certs)
    IS_REDHAT_DOMAIN="false"
    if echo "$API_HOSTNAME" | grep -qE '\.openshiftapps\.com$|\.devshift\.org$|\.openshiftapps\.net$'; then
        IS_REDHAT_DOMAIN="true"
    fi

    # Check for custom certificate configuration (only if not a Red Hat managed domain)
    HAS_CUSTOM_CERT="false"
    if [ "$IS_REDHAT_DOMAIN" = "false" ]; then
        NAMED_CERTS=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}' 2>&1`
        if [ -n "$NAMED_CERTS" ] && [ "$NAMED_CERTS" != "null" ]; then
            # Verify the secret actually exists
            SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}' 2>&1`
            if [ -n "$SECRET_NAME" ] && [ "$SECRET_NAME" != "null" ]; then
                oc get secret "${SECRET_NAME}" -n openshift-config >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    HAS_CUSTOM_CERT="true"
                fi
            fi
        fi
    fi

    # Determine certificate type
    if [ "$IS_KUBE_SIGNER" = "true" ]; then
        CERT_TYPE="OpenShift-Managed"
    elif [ "$IS_REDHAT_DOMAIN" = "true" ]; then
        CERT_TYPE="RedHat-Managed"
    elif [ "$HAS_CUSTOM_CERT" = "true" ]; then
        # Determine if well-known or private CA
        if echo "$ISSUER" | grep -qE "Let's Encrypt|DigiCert|GlobalSign|GeoTrust|Sectigo|Entrust"; then
            CERT_TYPE="Custom-WellKnown"
        else
            CERT_TYPE="Custom-SelfSigned"
        fi
    else
        # Cannot determine certificate type - mark as unknown
        CERT_TYPE="Unknown"
        print_warning "Unable to determine certificate type, marked as Unknown" >&2
    fi

    # Get certificate details
    CURRENT_LEAF_SUBJECT=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -subject`
    CURRENT_LEAF_ISSUER=`openssl x509 -in "${TEMP_DIR}/serving-cert.pem" -noout -issuer`

    # Get CA bundle based on certificate type
    case "$CERT_TYPE" in
        "OpenShift-Managed")
            CA_BUNDLE=`oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' 2>&1`
            if [ $? -eq 0 ]; then
                echo "$CA_BUNDLE" > "${TEMP_DIR}/ca-bundle.crt"
            fi
            ;;
        "RedHat-Managed")
            # No CA bundle needed for well-known CAs
            ;;
        "Custom-WellKnown"|"Custom-SelfSigned")
            SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}' 2>&1`
            if [ -n "$SECRET_NAME" ] && [ "$SECRET_NAME" != "null" ]; then
                CA_BUNDLE=`oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt --to=- 2>/dev/null`
                if [ $? -eq 0 ]; then
                    echo "$CA_BUNDLE" > "${TEMP_DIR}/ca-bundle.crt"
                fi
            fi
            ;;
    esac

    # Check if root CA is included
    CURRENT_ROOT_INCLUDED="no"
    CURRENT_ROOT_CA=""
    if [ -f "${TEMP_DIR}/ca-bundle.crt" ]; then
        CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "${TEMP_DIR}/ca-bundle.crt")
        for i in $(seq 1 ${CERT_COUNT}); do
            SUBJ=$(awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${TEMP_DIR}/ca-bundle.crt" | openssl x509 -noout -subject 2>/dev/null)
            ISS=$(awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${TEMP_DIR}/ca-bundle.crt" | openssl x509 -noout -issuer 2>/dev/null)

            # Check if this is a self-signed certificate (subject == issuer)
            if [ "${SUBJ#subject=}" = "${ISS#issuer=}" ]; then
                CURRENT_ROOT_INCLUDED="yes"
                CURRENT_ROOT_CA="$SUBJ"
                break
            fi
        done

        # If no root CA found, get issuer of last cert in chain (that's the root CA)
        if [ -z "$CURRENT_ROOT_CA" ]; then
            LAST_CERT_ISSUER=$(awk "/BEGIN CERTIFICATE/ {n++} n==${CERT_COUNT}" "${TEMP_DIR}/ca-bundle.crt" | openssl x509 -noout -issuer 2>/dev/null)
            CURRENT_ROOT_CA="${LAST_CERT_ISSUER:-$CURRENT_LEAF_ISSUER}"
        fi
    else
        CURRENT_ROOT_CA="$CURRENT_LEAF_ISSUER"
    fi

    return 0
}

#──────────────────────────────────────────────────────────────────────────────
# normalize_dn
# Extracts CN from a Distinguished Name string
# Usage: normalized=$(normalize_dn "$dn_string")
#──────────────────────────────────────────────────────────────────────────────
normalize_dn() {
    local dn="${1#subject=}"
    dn="${dn#issuer=}"
    echo "$dn" | grep -o 'CN[[:space:]]*=[[:space:]]*[^,]*' | head -1 | sed 's/CN[[:space:]]*=[[:space:]]*//'
}

#──────────────────────────────────────────────────────────────────────────────
# normalize_full_dn
# Normalizes a full Distinguished Name string for comparison
# Removes 'subject=' and 'issuer=' prefixes and normalizes spacing
# Usage: normalized=$(normalize_full_dn "$dn_string")
#──────────────────────────────────────────────────────────────────────────────
normalize_full_dn() {
    local dn="${1#subject=}"
    dn="${dn#issuer=}"
    # Normalize spacing around = and ,
    echo "$dn" | sed 's/[[:space:]]*=[[:space:]]*/=/g; s/[[:space:]]*,[[:space:]]*/,/g' | tr -d '\n'
}
