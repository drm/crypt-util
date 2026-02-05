#!/usr/bin/env bash

## Usage:
##
##	[KEYROOT=...] \
##	[PASSWORD_STORE_DIR=...] \
##		./migrate-to-pass.sh SECRETS_DIR PASS_INSERT_ROOT
##
## Provides a way to migrate a crypt-util managed set of secrets to 'pass'.
## Only provides a way to import the secrets, it doesn't bother with
## migrating 'whom' these secrets are shared with. Organize this yourself
## afterwards using the 'pass init -p ... [gpg id] [gpg id2]' command. See
## the 'pass' manpages for more info.
##
## KEYROOT
##		Where crypt-util stores the symmetric keys
##
## SECRETS_DIR
##		The directory containing secrets to be imported. Note that all
##		secrets are imported. I suggest clever use of `git rebase -i`
##		inside your password store if you wish to exclude some.
##
## PASS_INSERT_ROOT
## 		The sub directory to use in pass. With PASS_INSERT_ROOT 'foo/bar',
##		a secret with name 'baz' will be saved in 'foo/bar/baz'.
##
## PASSWORD_STORE_DIR
##		The password store dir for 'pass' to use.
##

set -euo pipefail

export SECRETS_DIR="${1?"Missing SECRETS_DIR"}"
export KEYROOT="${KEYROOT:-"$SECRETS_DIR/keys"}"
export PASS_INSERT_ROOT="${2:-}"
export PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-$(cd ~ && pwd)/.password-store}"

source "$(dirname "$0")/crypt.sh"

if ! [ -d "$SECRETS_DIR" ]; then
	echo "SECRETS_DIR is not a directory: ${SECRETS_DIR}" >&2
	exit 1
fi

if ! [ -d "$PASSWORD_STORE_DIR" ]; then
	cat <<-EOF >&2
		PASSWORD_STORE_DIR is not a directory: ${PASSWORD_STORE_DIR}.
		Please initialize it first using 'pass init'. You need to pass
		the PASSWORD_STORE_DIR environment variable if you do not with
		to use the default.
	EOF
	exit 1
fi
SECRETS_DIR="$(cd "$SECRETS_DIR" && pwd)"
PASSWORD_STORE_DIR="$(cd "$PASSWORD_STORE_DIR" && pwd)"

for f in $SECRETS_DIR/*; do
	if ! [ -r "$f" ]; then
		echo "$f is not a file.";
		exit 2;
	fi
	if [ -d "$f" ]; then
		echo "Skipping dir: '${f/$SECRETS_DIR\//}'"
	else
		tgt="$(basename "$f")"
		if [ "$PASS_INSERT_ROOT" ]; then
			tgt="$PASS_INSERT_ROOT/$tgt"
		fi

		if ! cat "$f" \
			| decrypt \
			| pass insert -e "$tgt" >/dev/null; then
			echo "Failure to decrypt $f" >&2
		else
			echo "'${f/$SECRETS_DIR\//}' inserted in ${PASSWORD_STORE_DIR} as $tgt" >&2
		fi
	fi
done
