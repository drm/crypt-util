#!/bin/bash

set -euo pipefail

# Public key encryption
encrypt() {
	local pubkey_file="$1"

	openssl \
		pkeyutl \
		-encrypt \
		-inkey <(ssh-keygen -f "$pubkey_file" -e -m pem 2>/dev/null) \
		-pubin \
		-out -
}

# RSA private key decryption
decrypt() {
	openssl \
		pkeyutl \
		-decrypt \
		-inkey <(openssl rsa -in ~/.ssh/id_rsa -outform pem 2>/dev/null) \
		-out -
}

digest() {
	local pubkey_file="$1"
	ssh-keygen -f $pubkey_file -e -m pem | openssl pkey -pubin -outform DER | openssl dgst -sha256 | awk '{print $2}'
}

_print_sym_key() {
	cat ./keys/$(digest ~/.ssh/id_rsa.pub) | decrypt
}

share-key() {
	local pubkey_file="$1"

	_print_sym_key | encrypt $pubkey_file | ./keys/$(digest "$pubkey_file")
}

init-key() {
	cat | encrypt ~/.ssh/id_rsa.pub > ./keys/$(digest ~/.ssh/id_rsa.pub)
}

symmetric-encrypt() { 
	openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:$(_print_sym_key) $@ -out -
}

symmetric-decrypt() { 
	openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:$(_print_sym_key) -out -
}

echo "Testing 123" | symmetric-encrypt > encrypted
cat ./encrypted | symmetric-decrypt

rm encrypted
