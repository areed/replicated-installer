#!/bin/bash

set -e

AIRGAP=0
MIN_DOCKER_VERSION="1.10.3" # k8s min
NO_PROXY=0
PINNED_DOCKER_VERSION="{{ pinned_docker_version }}"
SKIP_DOCKER_INSTALL=0
OFFLINE_DOCKER_INSTALL=0
NO_CE_ON_EE="{{ no_ce_on_ee }}"
KUBERNETES_ONLY=0

{% include 'common/common.sh' %}
{% include 'common/prompt.sh' %}
{% include 'common/system.sh' %}
{% include 'common/docker.sh' %}
{% include 'common/docker-version.sh' %}
{% include 'common/docker-install.sh' %}
{% include 'common/docker-swarm.sh' %}
{% include 'common/replicated.sh' %}
{% include 'common/ip-address.sh' %}
{% include 'common/proxy.sh' %}
{% include 'common/log.sh' %}
{% include 'common/kubernetes.sh' %}
{% include 'common/selinux.sh' %}
{% include 'common/airgap.sh' %}
{% include 'common/swap.sh' %}

KUBERNETES_MASTER_PORT="6443"
KUBERNETES_MASTER_ADDR="{{ kubernetes_master_addr }}"
KUBEADM_TOKEN="{{ kubeadm_token }}"
KUBEADM_TOKEN_CA_HASH="{{ kubeadm_token_ca_hash }}"
SERVICE_CIDR="10.96.0.0/12" # kubeadm default

joinKubernetes() {
    logStep "Join Kubernetes Node"
    set +e
    kubeadm join --discovery-token-ca-cert-hash "${KUBEADM_TOKEN_CA_HASH}" --token "${KUBEADM_TOKEN}" "${KUBERNETES_MASTER_ADDR}:${KUBERNETES_MASTER_PORT}"
    _status=$?
    set -e
    if [ "$_status" -ne "0" ]; then
        printf "${RED}Failed to join the kubernetes cluster.${NC}\n" 1>&2
        exit $?
    fi
    logSuccess "Node Joined successfully"
}

promptForToken() {
    if [ -n "$KUBEADM_TOKEN" ]; then
        return
    fi

    printf "Please enter the kubernetes discovery token.\n"
    while true; do
        printf "Kubernetes join token: "
        prompt
        if [ -n "$PROMPT_RESULT" ]; then
            KUBEADM_TOKEN="$PROMPT_RESULT"
            return
        fi
    done
}

promptForTokenCAHash() {
    if [ -n "$KUBEADM_TOKEN_CA_HASH" ]; then
        return
    fi

    printf "Please enter the discovery token CA's hash.\n"
    while true; do
        printf "Kubernetes discovery token CA hash: "
        prompt
        if [ -n "$PROMPT_RESULT" ]; then
            KUBEADM_TOKEN_CA_HASH="$PROMPT_RESULT"
            return
        fi
    done
}

promptForAddress() {
    if [ -n "$KUBERNETES_MASTER_ADDR" ]; then
        return
    fi

    printf "Please enter the Kubernetes master address.\n"
    printf "e.g. 10.128.0.4\n"
    while true; do
        printf "Kubernetes master address: "
        prompt
        if [ -n "$PROMPT_RESULT" ]; then
            KUBERNETES_MASTER_ADDR="$PROMPT_RESULT"
            return
        fi
    done
}

outro() {
    printf "\n"
    printf "\n"
    printf "Visit the following URL for help configuring the replication level in your storage cluster"
    printf "\nhttps://help.replicated.com/guides/ship-with-kubernetes/managing-storage/#replication"
    printf "\n"
    printf "\n"
}

################################################################################
# Execution starts here
################################################################################

require64Bit
requireRootUser
detectLsbDist
detectInitSystem
must_swapoff

while [ "$1" != "" ]; do
    _param="$(echo "$1" | cut -d= -f1)"
    _value="$(echo "$1" | grep '=' | cut -d= -f2-)"
    case $_param in
        airgap)
            # arigap implies "no proxy"
            AIRGAP=1
            NO_PROXY=1
            OFFLINE_DOCKER_INSTALL=1
            ;;
        bypass-storagedriver-warnings|bypass_storagedriver_warnings)
            BYPASS_STORAGEDRIVER_WARNINGS=1
            ;;
        ca)
            CA="$_value"
            ;;
        daemon-registry-address|daemon_registry_address)
            DAEMON_REGISTRY_ADDRESS="$_value"
            ;;
        docker-version|docker_version)
            PINNED_DOCKER_VERSION="$_value"
            ;;
        http-proxy|http_proxy)
            PROXY_ADDRESS="$_value"
            ;;
        no-docker|no_docker)
            SKIP_DOCKER_INSTALL=1
            ;;
        no-proxy|no_proxy)
            NO_PROXY=1
            ;;
        kubernetes-master-address|kubernetes_master_address)
            KUBERNETES_MASTER_ADDR="$_value"
            ;;
        kubeadm-token|kubeadm_token)
            KUBEADM_TOKEN="$_value"
            ;;
        kubeadm-token-ca-hash|kubeadm_token_ca_hash)
            KUBEADM_TOKEN_CA_HASH="$_value"
            ;;
        tags)
            OPERATOR_TAGS="$_value"
            ;;
        no-ce-on-ee|no_ce_on_ee)
            NO_CE_ON_EE=1
            ;;
        service-cidr|service_cidr)
            SERVICE_CIDR="$_value"
            ;;
        kubernetes-only|kubernetes_only)
            KUBERNETES_ONLY=1
            ;;
        *)
            echo >&2 "Error: unknown parameter \"$_param\""
            exit 1
            ;;
    esac
    shift
done

promptForAddress
promptForToken
promptForTokenCAHash

if [ "$NO_PROXY" != "1" ]; then
    if [ -z "$PROXY_ADDRESS" ]; then
        discoverProxy
    fi

    if [ -z "$PROXY_ADDRESS" ]; then
        promptForProxy
    fi
fi

exportProxy

if [ "$SKIP_DOCKER_INSTALL" != "1" ]; then
    if [ "$OFFLINE_DOCKER_INSTALL" != "1" ]; then
        installDockerK8s "$PINNED_DOCKER_VERSION" "$MIN_DOCKER_VERSION"
    else
        installDocker_1_12_Offline
    fi
    checkDockerDriver
    checkDockerStorageDriver
fi

if [ -n "$PROXY_ADDRESS" ]; then
    parseIpv4FromAddress "$KUBERNETES_MASTER_ADDR"
    # enable kubeadm to reach the K8s API server
    export no_proxy="$PARSED_IPV4,$SERVICE_CIDR"
    NO_PROXY_IP="$PARSED_IPV4"
    requireDockerProxy
fi

if [ "$RESTART_DOCKER" = "1" ]; then
    restartDocker
fi

if ps aux | grep -qE "[k]ubelet"; then
    logSuccess "Node Kubelet Initialized"
    exit 0
fi

installKubernetesComponents
systemctl enable kubelet && systemctl start kubelet

if [ "$AIRGAP" = "1" ]; then
    if [ "$KUBERNETES_ONLY" != "1" ]; then
        promptForDaemonRegistryAddress
        mkdir -p "/etc/docker/certs.d/$DAEMON_REGISTRY_ADDRESS"
        promptForCA
        echo "$(echo "$CA" | base64 --decode)" > "/etc/docker/certs.d/$DAEMON_REGISTRY_ADDRESS/ca.crt"
    fi
    airgapLoadKubernetesCommonImages
else
    docker pull registry:2.6.2
    docker tag registry:2.6.2 registry:2
fi

joinKubernetes

outro

exit 0
