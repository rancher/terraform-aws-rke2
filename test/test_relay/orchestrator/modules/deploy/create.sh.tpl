#!/usr/bin/env sh
DIR=$(pwd)

# Add ~/bin to PATH for age and aws
export PATH="$${HOME}/bin:$PATH"

# Handle age decryption if needed
SECRETS_DECRYPTED=0
if [ -n "$AGE_KEY_PATH" ] && [ -n "$SECRETS_PATH" ] && [ -f "$AGE_KEY_PATH" ] && [ -f "$SECRETS_PATH" ]; then
  DECRYPTED_SECRETS="/tmp/secrets.rc"
  echo "Decrypting secrets with age..."

  age -d -i "$AGE_KEY_PATH" -o "$DECRYPTED_SECRETS" "$SECRETS_PATH"
  if [ -f "$DECRYPTED_SECRETS" ]; then
    chmod +x "$DECRYPTED_SECRETS"
    # shellcheck disable=SC1090
    . "$DECRYPTED_SECRETS"
    SECRETS_DECRYPTED=1
  else
    echo "Failed to decrypt secrets"
    exit 1
  fi
else
  echo "No secrets to decrypt"
  exit 1
fi

# shellcheck disable=SC2154
cd "${deploy_path}" || exit
if [ -f ./envrc ]; then
  # shellcheck disable=SC1091
  . ./envrc
else
  echo "can't find envrc..."
  if [ $SECRETS_DECRYPTED -eq 1 ]; then rm -f "$DECRYPTED_SECRETS"; fi
  exit 1
fi

# Set up plugin cache directory
mkdir -p "$HOME/.terraform.d/plugin-cache"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
export TF_IN_AUTOMATION=1

terraform version

# shellcheck disable=SC2034
TF_CLI_ARGS_init=""
# shellcheck disable=SC2034
TF_CLI_ARGS_apply=""

# shellcheck disable=SC2154
${init_script}

# shellcheck disable=SC2154
MAX=${attempts}
EXITCODE=1
ATTEMPTS=0
E=1
E1=0
while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; do
  A=0
  while [ $E -gt 0 ] && [ $A -lt "$MAX" ]; do
    # shellcheck disable=SC2154
    timeout -k 1m "${timeout}" terraform apply -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
    E=$?
    if [ $E -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
    A=$((A+1))
  done
  # don't destroy if the last attempt fails
  if [ $E -gt 0 ] && [ $ATTEMPTS != $((MAX-1)) ]; then
    A1=0
    while [ $E1 -gt 0 ] && [ $A1 -lt "$MAX" ]; do
      timeout -k 1m "${timeout}" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
      E1=$?
      if [ $E1 -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
      A1=$((A1+1))
    done
  fi
  if [ $E -gt 0 ]; then
    echo "apply failed..."
  fi
  if [ $E1 -gt 0 ]; then
    echo "destroy failed..."
  fi
  if [ $E -gt 0 ] || [ $E1 -gt 0 ]; then
    EXITCODE=1
  else
    EXITCODE=0
  fi
  ATTEMPTS=$((ATTEMPTS+1))
  if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; then
    # shellcheck disable=SC2154
    echo "wait ${interval} seconds between attempts..."
    # shellcheck disable=SC2154
    sleep "${interval}"
  fi
done
if [ $ATTEMPTS -eq "$MAX" ]; then echo "max attempts reached..."; fi
if [ $EXITCODE -ne 0 ]; then echo "failure, exit code $EXITCODE..."; fi
if [ $EXITCODE -eq 0 ]; then
  echo "success...";
  terraform output -json -state="tfstate" > outputs.json
fi

# Cleanup decrypted secrets
if [ $SECRETS_DECRYPTED -eq 1 ] && [ -f "$DECRYPTED_SECRETS" ]; then
  rm -f "$DECRYPTED_SECRETS"
fi

cd "$DIR" || exit
exit $EXITCODE
