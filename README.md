# Encrypted files in git

Basics: encrypted files are shared using a symmetric key. The symmetric key is
encrypted in the repo, under a file with a name based on a digest of the public
RSA key.

The symmetric key can thus only be obtained by someone who has the matching
private key for any of the encrypted symmetric key files.

By sourcing the file in a shell, the encrypt and decrypt functions become 
available. They both read stdin and write to stdout, so the way to use this is:

```
echo "some secret" | encrypt > ./path/to/secret
cat path/to/secret | decrypt
```

Sharing the symmetric key with someone else can be done using the 'share-key'
function:

```
share-key path/to/id_rsa.pub
```
This decrypts the symmetric key (using the current user's private key),
encrypts it (using the passed public key) and writes it to `$KEYROOT/$HASH`,
where $HASH is a sha hash of that same public key.

Note that it must be an RSA key, other key types are not supported  (or cannot
be used to asymmetrically encrypt/decrypt in the first place).

# License
The code is licensed under the 'DBAD' license. Read https://dbad-license.org/
for more info.

