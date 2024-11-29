#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

env PS1="(crypt-util)" bash --rcfile "$ROOT/crypt.sh"
 


