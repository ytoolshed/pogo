#!/bin/sh -x

echo "--- create password-protected key"
umask 0066
/usr/bin/openssl genrsa -passout pass:asdf -aes256 -out /tmp/server.key.$$ 4096

echo "--- remove passphrase"
/usr/bin/openssl rsa -passin pass:asdf -in /tmp/server.key.$$ -out ./ssl.key
rm /tmp/server.key.$$

echo "--- generate cert"
/usr/bin/openssl req  -new -x509 -days 3650 -key ssl.key -out ssl.cert -config pogo.dn

echo "--- key/cert"
ls -la ssl.key ssl.cert

