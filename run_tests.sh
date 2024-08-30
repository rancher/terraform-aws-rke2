#!/bin/bash

run_tests() {
  # make sure the test_relay is ready
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "$REPO_ROOT/test/test_relay" || exit 1
  terraform init -upgrade
  cd "$REPO_ROOT" || exit 1

  echo "" > "/tmp/${IDENTIFIER}_test.log"
  if [ -d "./test" ]; then
    cd test || exit 1
  fi
  if [ -d "./tests" ]; then
    cd tests || exit 1
  fi
  cat <<'EOF'> "/tmp/${IDENTIFIER}_test-processor"
echo "Passed: "
jq -r '. | select(.Action == "pass") | select(.Test != null).Test' /tmp/$IDENTIFIER_test.log
echo " "
echo "Failed: "
jq -r '. | select(.Action == "fail") | select(.Test != null).Test' /tmp/$IDENTIFIER_test.log
echo " "
EOF
  chmod +x "/tmp/${IDENTIFIER}_test-processor"

  gotestsum \
    --format=standard-verbose \
    --jsonfile "/tmp/${IDENTIFIER}_test.log" \
    --post-run-command "bash /tmp/${IDENTIFIER}_test-processor" \
    -- \
    -parallel=3 \
    -failfast=1 \
    -timeout=300m \
    "$@"
}
if [ "" =  "$IDENTIFIER" ]; then
  IDENTIFIER="$(echo a-$RANDOM-d | base64 | tr -d '=')"
  export IDENTIFIER
fi
echo "id is: $IDENTIFIER..."
run_tests "$@"

if [ -z "$CI" ]; then
  echo "Clearing leftovers with Id $IDENTIFIER in $AWS_REGION..."
  sleep 60

  if [ "" != "$IDENTIFIER" ]; then
    while [ "" != "$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER")" ]; do
      leftovers --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER" --no-confirm;
      sleep 10;
    done
    while [ "" != "$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --type="ec2-key-pair" --filter="tf-$IDENTIFIER")" ]; do
      leftovers --iaas=aws --aws-region="$AWS_REGION" --type="ec2-key-pair" --filter="tf-$IDENTIFIER" --no-confirm;
      sleep 10;
    done
  fi

  echo "done"
fi
