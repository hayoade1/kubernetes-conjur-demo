#!/bin/bash
set -euo pipefail

. utils.sh

if [ $PLATFORM = 'openshift' ]; then
    docker login -u _ -p $(oc whoami -t) $DOCKER_REGISTRY_PATH
fi

announce "Building and pushing test app images."

readonly APPS=(
  "init"
  "sidecar"
)

pushd test_app_summon
  if [ $PLATFORM = 'openshift' ]; then
    docker build -t test-app-builder -f Dockerfile.builder .

    # retrieve the summon binaries
    id=$(docker create test-app-builder)
    docker cp $id:/usr/local/lib/summon/summon-conjur ./
    docker cp $id:/usr/local/bin/summon ./
    docker rm -v $id
  fi

  for app_type in "${APPS[@]}"; do
    # prep secrets.yml
    sed -e "s#{{ TEST_APP_NAME }}#test-summon-$app_type-app#g" ./secrets.template.yml > secrets.yml

    dockerfile="Dockerfile"
    if [ $PLATFORM = 'openshift' ]; then
      dockerfile="Dockerfile.oc"
    fi

    docker build \
      -t test-app:$CONJUR_NAMESPACE_NAME \
      -f $dockerfile .

    test_app_image=$(platform_image "test-$app_type-app")
    docker tag test-app:$CONJUR_NAMESPACE_NAME $test_app_image

    if [[ is_minienv != true ]]; then
      docker push $test_app_image
    fi
  done
popd

pushd pg

  if [ $PLATFORM = 'openshift' ]; then
    s2i build . centos/postgresql-95-centos7 test-app-pg-builder
    docker build \
      -t test-app-pg:$CONJUR_NAMESPACE_NAME \
      -f Dockerfile.oc \
      .
  else
    docker build -t test-app-pg:$CONJUR_NAMESPACE_NAME .
  fi

  test_app_pg_image=$(platform_image test-app-pg)
  docker tag test-app-pg:$CONJUR_NAMESPACE_NAME $test_app_pg_image

  if [[ is_minienv != true ]]; then
    docker push $test_app_pg_image
  fi
popd

if [[ $LOCAL_AUTHENTICATOR == true ]]; then
  # Re-tag the locally-built conjur-authn-k8s-client:dev image
  authn_image=$(platform_image conjur-authn-k8s-client)
  docker tag conjur-authn-k8s-client:dev $authn_image

  if [[ is_minienv != true ]]; then
    docker push $authn_image
  fi
fi
