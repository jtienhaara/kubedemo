#!/bin/sh

if test $# -lt 2
then
    echo "Usage: $0 (encrypted-env-file) (command) (arg)..." >&2
    echo "" >&2
    echo "Runs the specified command using 'sops exec-env (encrypted-env-file)'," >&2
    echo "so that the environment variables defined in encrypted-env-file" >&2
    echo "are available to the command(s) being run." >&2
    echo "" >&2
    echo "The command and arguments are executed inside bash -c, so multiple" >&2
    echo "commands can, in fact, be run (such as piped together or anded/ored" >&2
    echo "commands, taking advantage of shell syntax)." >&2
    echo "" >&2
    echo "It is assumed that the environment variables to decrypt have" >&2 
    echo "been set:" >&2
    echo "" >&2
    echo "    KUBEDEMO_PUBLIC_KEY: The AGE key used to encrypt (encrypted-env-file)." >&2
    echo "    KUBEDEMO_PRIVATE_KEY: The AGE key that will be used to decrypt" >&2
    echo "        (encrypted-env-file)." >&2
    exit 1
fi

ENCRYPTED_ENV_FILE=$1
shift
COMMAND_TO_RUN=$@

if test -z "$KUBEDEMO_PUBLIC_KEY" \
        -o -z "$KUBEDEMO_PRIVATE_KEY"
then
    echo "ERROR KUBEDEMO_PUBLIC_KEY ($KUBEDEMO_PUBLIC_KEY) and/or KUBEDEMO_PRIVATE_KEY not set" >&2
    exit 1
elif test ! -f "$ENCRYPTED_ENV_FILE"
then
    echo "ERROR No such AGE-encrypted environment file: $ENCRYPTED_ENV_FILE" >&2
    exit 1
fi

#
# Unfortunately sops exec-env doesn't have any way to allow options
# to be passed to the command it runs.  For example, trying to run
# sops ... exec-env ... bash -c '...script...' fails with
# "error: missing file to decrypt".
#
# So we execute bash without any parameters, then pass in everything
# we want to run via pipe.
#
# Ugly but it works.
#
echo "$COMMAND_TO_RUN" \
    | SOPS_AGE_KEY=$KUBEDEMO_PRIVATE_KEY \
          sops --age "$KUBEDEMO_PUBLIC_KEY" \
          exec-env "$ENCRYPTED_ENV_FILE" \
              bash
EXIT_CODE=$?
exit $EXIT_CODE
