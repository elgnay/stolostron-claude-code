#!/bin/bash

# ACM Detection Library
# Shared functions for detecting and analyzing ACM installation

# Requires: KUBECONFIG to be exported
# Requires: lib/common.sh to be sourced for print functions

#──────────────────────────────────────────────────────────────────────────────
# detect_acm_configuration
# Detects ACM installation and configuration
# Sets global variables:
#   - MCH_FOUND (true/false)
#   - MCH_NAMESPACE
#   - MCH_NAME
#   - MCH_VERSION
#   - MCH_STATUS
#   - SERVER_VERIFICATION_STRATEGY
#──────────────────────────────────────────────────────────────────────────────
detect_acm_configuration() {
    # Check for MultiClusterHub resources
    MCH_FOUND=false
    MCH_STATUS=""
    MCH_NAMESPACE=""
    MCH_NAME=""
    MCH_VERSION=""

    MCH_OUTPUT=`oc get multiclusterhub -A 2>&1`
    MCH_EXIT_CODE=$?

    if [ $MCH_EXIT_CODE -ne 0 ]; then
        if echo "$MCH_OUTPUT" | grep -q "No resources found"; then
            MCH_FOUND=false
        elif echo "$MCH_OUTPUT" | grep -q "doesn't have a resource type"; then
            MCH_FOUND=false
        else
            error "Failed to query MultiClusterHub: $MCH_OUTPUT"
            return 1
        fi
    elif echo "$MCH_OUTPUT" | grep -qv "^NAMESPACE"; then
        MCH_FOUND=true
        MCH_NAMESPACE=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $1}' | head -n 1`
        MCH_NAME=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $2}' | head -n 1`
        MCH_STATUS=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $3}' | head -n 1`

        MCH_VERSION=`oc get multiclusterhub -A -o jsonpath='{.items[0].status.currentVersion}' 2>/dev/null`
        if [ -z "$MCH_VERSION" ]; then
            MCH_VERSION="Unknown"
        fi
    fi

    # Check for ACM Operator if no MultiClusterHub found
    OPERATOR_FOUND=false
    if [ "$MCH_FOUND" = false ]; then
        OPERATOR_OUTPUT=`oc get pods -n open-cluster-management -l app=multiclusterhub-operator 2>&1`
        OPERATOR_EXIT_CODE=$?

        # Check if pods exist (not "No resources found" message)
        if [ $OPERATOR_EXIT_CODE -eq 0 ] && echo "$OPERATOR_OUTPUT" | grep -qv "^NAME" && ! echo "$OPERATOR_OUTPUT" | grep -q "No resources found"; then
            OPERATOR_FOUND=true
        fi
    fi

    # Get ServerVerificationStrategy if ACM is installed
    SERVER_VERIFICATION_STRATEGY=""
    if [ "$MCH_FOUND" = true ]; then
        KLUSTERLET_CONFIG_OUTPUT=`oc get klusterletconfig global 2>&1`
        if [ $? -eq 0 ]; then
            SERVER_VERIFICATION_STRATEGY=`oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}' 2>/dev/null`
        fi

        if [ -z "$SERVER_VERIFICATION_STRATEGY" ]; then
            SERVER_VERIFICATION_STRATEGY="UseAutoDetectedCABundle"
        fi
    fi

    return 0
}
