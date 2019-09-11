#!/bin/bash

. ./install_scripts/templates/common/common.sh
. ./install_scripts/templates/common/registryproxy.sh

test_configureRegistryProxyAddressOverride_UrlPrefix()
{
    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD=url-prefix \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY= \
        configureRegistryProxyAddressOverride
    assertEquals "localhost:8081" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "quay-remote/" "$REGISTRY_PATH_PREFIX"

    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD=url-prefix \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY=quay-custom \
        configureRegistryProxyAddressOverride
    assertEquals "localhost:8081" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "quay-custom/" "$REGISTRY_PATH_PREFIX"

    # default access method is url-prefix
    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD= \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY=quay-custom \
        configureRegistryProxyAddressOverride
    assertEquals "localhost:8081" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "quay-custom/" "$REGISTRY_PATH_PREFIX"

    # empty artifactory-address
    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD= \
        ARTIFACTORY_ADDRESS= \
        ARTIFACTORY_QUAY_REPO_KEY= \
        configureRegistryProxyAddressOverride
    assertEquals "" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "" "$REGISTRY_PATH_PREFIX"
}

test_configureRegistryProxyAddressOverride_Subdomain()
{
    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD=subdomain \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY= \
        configureRegistryProxyAddressOverride
    assertEquals "quay-remote.localhost:8081" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "" "$REGISTRY_PATH_PREFIX"

    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD=subdomain \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY=quay-custom \
        configureRegistryProxyAddressOverride
    assertEquals "quay-custom.localhost:8081" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "" "$REGISTRY_PATH_PREFIX"
}

test_configureRegistryProxyAddressOverride_Port()
{
    REGISTRY_ADDRESS_OVERRIDE=
    REGISTRY_PATH_PREFIX=
    ARTIFACTORY_ACCESS_METHOD=port \
        ARTIFACTORY_ADDRESS=localhost:8081 \
        ARTIFACTORY_QUAY_REPO_KEY=8000 \
        configureRegistryProxyAddressOverride
    assertEquals "localhost:8000" "$REGISTRY_ADDRESS_OVERRIDE"
    assertEquals "" "$REGISTRY_PATH_PREFIX"
}

test_parseBasicAuth()
{
    parseBasicAuth "YWRtaW46cGFzc3dvcmQ="
    assertEquals "admin" "$BASICAUTH_USERNAME"
    assertEquals "password" "$BASICAUTH_PASSWORD"
}

. shunit2
