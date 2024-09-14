#!/bin/bash

HOME="$(cd ~ && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-$HOME/.ssh/id_rsa}"
PUBLIC_KEY="${PUBLIC_KEY:-$HOME/.ssh/id_rsa.pub}"
KEYROOT="${KEYROOT:-./keys}"

set -euo pipefail

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

_sym_key() {
	cat $KEYROOT/$(_digest "$PUBLIC_KEY") \
		| _rsa-decrypt
}

share-key() {
	local pubkey_file="$1"
	_sym_key \
		| _rsa-encrypt $pubkey_file \
		> $KEYROOT/$(_digest "$pubkey_file")
}

init-key() {
	cat \
		| _rsa-encrypt $PUBLIC_KEY \
		> $KEYROOT/$(_digest $PUBLIC_KEY)
}

encrypt() { 
	openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:$(_sym_key) -out -
}

decrypt() { 
	openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:$(_sym_key) -out -
}
