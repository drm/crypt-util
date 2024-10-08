# Encrypted files in git

Basics: encrypted files are shared using a symmetric key. The symmetric key is
encoded in the repo, under a file with a name based on a digest of the public
ssh key.

The symmetric key can thus only be obtained by someone who has the matching
private key for any of the encryped symmetric key files.

# License
The code is licensed under the 'DBAD' license. Read https://dbad-license.org/
for more info.

