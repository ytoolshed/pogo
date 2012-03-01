
##########################################################################
# CA TEST CERT 
##########################################################################
  # generate a clear-text private key for the CA
openssl genrsa -out ca.key 1024

  # generate a CSR
openssl req -new -key ca.key -out ca.csr <<EOT
US
California
San Francisco
Sloppy CA Inc. - We approve Anything without checking!
IT
somewhere.com
a@b.com
.
.
EOT

  # Generate self-signed cert
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt

rm -f index.txt
touch index.txt

echo 01 >serial

cat >ca.conf <<EOT
  # CA config file
[ ca ]
default_ca      = CA_default            # The default ca section

[ CA_default ]
dir            = .                # top dir
database       = index.txt        # index file.
new_certs_dir  = .

certificate    = ca.crt           # The CA cert
serial         = serial           # serial no file
private_key    = ca.key
RANDFILE       = .rand            # random number file

default_days   = 365                   # how long to certify for
default_crl_days= 30                   # how long before next CRL
default_md     = md5                   # md to use

email_in_dn    = no                    # Don't add the email into cert DN
policy         = policy_any            # default policy

name_opt       = ca_default            # Subject name display option
cert_opt       = ca_default            # Certificate display option
copy_extensions = none                 # Don't copy extensions from request

[ policy_any ]
countryName            = supplied
stateOrProvinceName    = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

EOT

##########################################################################
# SERVER TEST CERT 
##########################################################################
  # generate a clear-text private key for the dispatcher
openssl genrsa -out dispatcher.key 1024

openssl req -new -key dispatcher.key -out dispatcher.csr <<EOT
US
California
San Francisco
Noname Inc.
IT
dispatcher-x.pogo.nonexist.com
a@b.com
.
.
EOT

  # CA signs the dispatcher cert
openssl ca -batch -days 365 -config ca.conf -in dispatcher.csr -keyfile ca.key -out dispatcher.crt

##########################################################################
# CLIENT CERT 
##########################################################################

  # generate a clear-text private key
openssl genrsa -out worker.key 1024

  # generate a CSR
openssl req -new -key worker.key -out worker.csr <<EOT
US
California
San Francisco
Noname Inc.
IT
worker-x.pogo.nonexist.com
a@b.com
.
.
EOT

  # CA signs the dispatcher cert
openssl ca -batch -days 365 -config ca.conf -in worker.csr -keyfile ca.key -out worker.crt
