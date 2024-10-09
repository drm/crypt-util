#!/bin/bash

cleanup() {
	rm -f {alice,bob}.* secret{1,2} 
	rm -rf "./test-keyroot"
}

trap cleanup EXIT

set -euo pipefail

set -x

ssh-keygen -t rsa -N "" -f ./alice.key 
ssh-keygen -t rsa -N "" -f ./bob.key 

# Keys are written in OpenSSH format; this converts them to RSA format.
ssh-keygen -m pem -p -N "" -f ./alice.key
ssh-keygen -m pem -p -N "" -f ./bob.key

as() {
	local user="$1"

	cat <<-EOF
		set -euo pipefail

		echo "### Running as $user ###"
		
		export PRIVATE_KEY=$user.key
		export PUBLIC_KEY=$user.key.pub
		export KEYROOT="./test-keyroot"

		source crypt.sh
	EOF
}

/bin/bash <<-EOF
	$(as alice)

	openssl rand -hex 100 | init-key 
	share-key bob.key.pub
EOF

/bin/bash <<-EOF
	$(as bob)

	echo "bob's secret" | encrypt > ./secret1 
EOF

/bin/bash <<-EOF
	$(as alice)

	cat ./secret1 | decrypt
	
	echo "alice's secret" | encrypt > ./secret2
	cat ./secret2 | decrypt
EOF

/bin/bash <<-EOF
	$(as bob)

	cat ./secret2 | decrypt
EOF

set +x
echo "All good."

