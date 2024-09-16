#!/bin/bash

HOME="$(cd ~ && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-$HOME/.ssh/id_rsa}"
PUBLIC_KEY="${PUBLIC_KEY:-${PRIVATE_KEY}.pub}"
KEYROOT="${KEYROOT:-./keys}"

set -euo pipefail

_require_rsa_key() {
	local keyfile="${1:-$PUBLIC_KEY}"
	if ! [ -f "$keyfile" ]; then
		echo "$keyfile is missing";
		echo ""
		echo "There are several ways to solve this:"
		echo " 1. Generate a new keypair (ssh-keygen -t rsa -f ${keyfile/.pub/}"
		echo " 2. Or specify the keypair using the PRIVATE_KEY override as such:"
		echo "    PRIVATE_KEY=/path/to/rsa/key ./the-script.sh"
		echo " 3. Or symlink a keypair in $HOME/.ssh"
		echo ""
		exit 2;
	fi
}

# Public key encryption
_rsa-encrypt() {
	local pubkey_file="$1"

	openssl \
		pkeyutl \
		-encrypt \
		-inkey <(ssh-keygen -f "$pubkey_file" -e -m pem 2>/dev/null) \
		-pubin \
		-out -
}

# RSA private key decryption
_rsa-decrypt() {
	openssl \
		pkeyutl \
		-decrypt \
		-inkey <(openssl rsa -in $PRIVATE_KEY -outform pem 2>/dev/null) \
		-out -
}

_digest() {
	local pubkey_file="$1"
	ssh-keygen \
		-f $pubkey_file \
		-e \
		-m pem \
		| openssl pkey -pubin -outform DER \
		| openssl dgst -sha256 \
		| awk '{print $2}'
}

_aes_key() {
	_require_rsa_key "$PUBLIC_KEY"

	cat $KEYROOT/$(_digest "$PUBLIC_KEY") \
		| _rsa-decrypt
}

share-key() {
	local pubkey_file="$1"
	local key_file="$KEYROOT/$(_digest "$pubkey_file")"

	_aes_key \
		| _rsa-encrypt $pubkey_file \
		> $key_file
	echo "$key_file written."
}

revoke-key() {
	local pubkey_file="$1"
	local key_file="$KEYROOT/$(_digest "$pubkey_file")"
	
	rm -fv $KEYROOT/$(_digest "$pubkey_file")
}

init-key() {
	local key_file="$KEYROOT/$(_digest "$PUBLIC_KEY")"
	cat \
		| _rsa-encrypt $PUBLIC_KEY \
		> $key_file

	echo "$key_file written."
}

encrypt() { 
	openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:$(_aes_key) -out -
}

decrypt() { 
	openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:$(_aes_key) -out -
}
