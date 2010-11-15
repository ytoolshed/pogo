#!/bin/sh 

umask 0066
dir=$1

if [ -z "$dir" ]; then
  echo "Usage: $0 <dir>" >&2
  exit 1
fi


echo "---creating dispatcher keypair in $dir"
openssl req -batch \
            -config dispatcher_ssl.cnf \
            -x509 \
            -newkey rsa:2048 \
            -days 365 \
            -nodes \
            -out $dir/pogo-dispatcher.crt \
            -keyout $dir/pogo-dispatcher.key

echo "---creating worker keypair in $dir"
openssl req -batch \
            -config worker_ssl.cnf \
            -x509 \
            -newkey rsa:2048 \
            -days 365 \
            -nodes \
            -out $dir/pogo-worker.crt \
            -keyout $dir/pogo-worker.key

# vim:syn=sh:ts=2:sw=2:et:ai
