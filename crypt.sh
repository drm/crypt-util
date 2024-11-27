#!/bin/bash

HOME="$(cd ~ && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-$HOME/.ssh/id_rsa}"
PUBLIC_KEY="${PUBLIC_KEY:-${PRIVATE_KEY}.pub}"
KEYROOT="${KEYROOT:-./keys}"

set -euo pipefail

_require_rsa_key() {
	local keyfile="${1}"
	if ! [ -f "$keyfile" ]; then
		cat >&2 <<-EOF
			$keyfile is missing.

			You will need an RSA keypair to solve this:

				ssh-keygen -t rsa -f ${keyfile/.pub/}
		EOF
		exit 2;
	fi
}

# Public key encryption
_rsa-encrypt() {
	local pubkey_file="$1"

	ssh-keygen -f "$pubkey_file" -e -m pem > "${pubkey_file}.pem" 

	openssl \
		pkeyutl \
		-encrypt \
		-inkey "${pubkey_file}.pem" \
		-pubin \
		-out -
}

# RSA private key decryption
_rsa-decrypt() {
	local privkey_file="${PRIVATE_KEY}"
	local pem_file="${privkey_file}.pem"

	rm -f $pem_file
	if ! openssl rsa -in $privkey_file -outform pem -out - > $pem_file 2>/dev/null; then
		echo "Failed to extract PEM for $privkey_file." >&2
		if grep 'OPENSSH PRIVATE KEY' $privkey_file >/dev/null; then
			cat >&2 <<-EOF 
			Your private key seems to be in OpenSSH format, which is not supported by openssl.

			Try converting it using the following command:

			    cp $privkey_file{,.bak}
			    ssh-keygen -p -m PEM -f $privkey_file
			
			Note that this only changes the file format, not the actual key itself, and this 
			remains compatible with OpenSSH. When unsure, verify the fingerprints as such:

			    ssh-keygen -l -f $privkey_file
			    ssh-keygen -l -f $privkey_file.bak
			EOF
		fi
		exit 2;
	fi
	chmod 400 "$pem_file"
	
	if ! openssl \
		pkeyutl \
		-decrypt \
		-inkey $pem_file \
		-out -; then
		echo "Failed to decrypt using $pem_file." >&2
		exit 3;
	fi
	
	rm -f "$pem_file"
}

_digest() {
	local pubkey_file="$1"

	_require_rsa_key "$pubkey_file"
	ssh-keygen \
		-f $pubkey_file \
		-e \
		-m pem \
		| openssl pkey -pubin -outform DER \
		| openssl dgst -sha256 \
		| awk '{print $2}'
}

_aes_key() {
	local shared_key_file; shared_key_file="$KEYROOT/$(_digest "$PUBLIC_KEY")"
	if ! test -f "$shared_key_file"; then
		echo "$shared_key_file is missing." >&2
		exit 3;
	fi

	cat $shared_key_file | _rsa-decrypt
}

share-key() {
	local pubkey_file="$1"
	local key_file; key_file="$KEYROOT/$(_digest "$pubkey_file")"

	_aes_key \
		| _rsa-encrypt $pubkey_file \
		> $key_file
	echo "${key_file} written."
}

revoke-key() {
	local pubkey_file="$1"
	local key_file; key_file="$KEYROOT/$(_digest "$pubkey_file")"

	rm -fv "$key_file"
	echo "${key_file} removed."
}

init-key() {
	local key_file; key_file="$KEYROOT/$(_digest "$PUBLIC_KEY")"
	mkdir -p "$(dirname "$key_file")"
	cat \
		| _rsa-encrypt $PUBLIC_KEY \
		> $key_file

	echo "$key_file written."
}

encrypt() { 
	local key; key="$(_aes_key)"

	if [ "$key" != "" ]; then
		openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:$key -out -
	fi
}

decrypt() {
	local key; key="$(_aes_key)"

	if [ "$key" != "" ]; then
		openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:$key -out -
	fi
}
