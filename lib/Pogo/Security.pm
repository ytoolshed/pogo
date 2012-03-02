###########################################
package Pogo::Security;
###########################################
use strict;
use warnings;

our $VERSION = $Pogo::VERSION;

1;

__END__

=head1 NAME

Pogo::Security - Musings on different security aspects in Pogo

=head1 DESCRIPTION

This is a pure documentation module, explaining some of the security 
choices made in Pogo and how to enable them.

=head2 Secure Communication Channels

Information sent from the dispatchers to the workers can contain 
sensitive information like passwords. For that reason, Pogo uses
the SSL implementation in C<AnyEvent::TLS> (which in turn uses C<Net::SSLeay>,
which uses C<openssl>).

=head2 SSL Certificates

When a worker connects to a dispatcher, the worker starts an SSL handshake.
It retrieves a server certificate from the dispatcher and verifies it. It 
also provides a client certificate that the server verifies to see if the
worker is legit.

Both server and client certificates are signed by the same CA ("Certificate
Authority", a clearing house for server/client certs), and both
client and server have that CA cert installed to verify the server/client
certs they receive from the other side.

Instead of paying an established CA (like Verisign) for the certs, you can 
whip up 
your own CA cert, which is then used in turn to sign the worker and 
dispatcher certs. First, create a secret key for the CA and make sure
this key is always kept secret:

      # generate a clear-text private key for the CA
    openssl genrsa -out ca.key 1024

Then, create a Certificate Signing Request for the CA cert:

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

As this is the 'root' cert in our PKI, we use the CA's private key
to self-sign it:

      # Generate self-signed cert
    openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt

Next, we need to set up some housekeeping for starting to operate our
new CA:

    rm -f index.txt
    touch index.txt

    echo 01 >serial

    cat >ca.conf <<EOT
      # CA config file
    [ ca ]
    default_ca      = CA_default      # The default ca section
    
    [ CA_default ]
    dir            = .                # top dir
    database       = index.txt        # index file.
    new_certs_dir  = .
    
    certificate    = ca.crt           # The CA cert
    serial         = serial           # serial no file
    private_key    = ca.key
    RANDFILE       = .rand            # random number file
    
    default_days   = 365              # how long to certify for
    default_crl_days= 30              # how long before next CRL
    default_md     = md5              # md to use
    
    email_in_dn    = no               # Don't add the email into cert DN
    policy         = policy_any       # default policy

    name_opt       = ca_default       # Subject name display option
    cert_opt       = ca_default       # Certificate display option
    copy_extensions = none            # Don't copy extensions from request
    
    [ policy_any ]
    countryName            = supplied
    stateOrProvinceName    = optional
    organizationName       = optional
    organizationalUnitName = optional
    commonName             = supplied
    emailAddress           = optional
    
    EOT

Now we're ready to create dispatcher and worker certs and sign
them by our own CA. First the server (dispatcher) cert:

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
    openssl ca -batch -days 365 -config ca.conf -in dispatcher.csr \
      -keyfile ca.key -out dispatcher.crt
    
Then the client (worker) cert:

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
    openssl ca -batch -days 365 -config ca.conf -in worker.csr \
      -keyfile ca.key -out worker.crt

=head2 SSL Cert Installation

That's it, now in order to install those certs/keys on the 
respective hosts, we need the following files on the dispatcher:

=over 4

=item *

server cert (C<dispatcher.crt>)

=item *

server private key (C<dispatcher.key>)

=item *

CA cert (C<ca.crt>)

=back

To start a dispatcher in SSL mode, use

    my $dispatcher = Pogo::Dispatcher->new(
        ssl             => 1,
        dispatcher_key  => '/path/to/dispatcher_key',
        dispatcher_cert => '/path/to/dispatcher_cert',
        ca_cert         => '/path/to/ca_cert',
    );

Conversely, the worker needs:

=over 4

=item *

client cert (C<worker.crt>)

=item *

client private key (C<worker.key>)

=item *

CA cert (C<ca.crt>)

=back

To start a worker in SSL mode, use

    my $worker = Pogo::Worker->new(
        dispatchers => [ "localhost:xxxx" ],
        ssl         => 1,
        worker_key  => '/path/to/worker_key',
        worker_cert => '/path/to/worker_cert',
        ca_cert     => '/path/to/ca_cert',
    );

=head2 Debugging SSL

Debugging SSL can be a frustrating experience because the 
used libraries aren't telling much about what went wrong if
the SSL handshake fails. A failing handshake can be caused
by a variety of mistakes, and to get to the bottom of the
problem, it is very helpful to use openssl's C<s_client> and
C<s_server> implementations. These standalone programs are
quite verbose and will tell what exactly is going on during
the different SSL steps and what kind of certs or keys are 
used.

You can use both C<s_server> and C<s_client> to test your certs. For
details, check the C<man s_server> and C<man s_client> manual pages.

Here's an example. First, start the server:

   $ openssl s_server -accept 1234 \
       -cert dispatcher.crt \
       -key dispatcher.key \
       -CAfile ca.crt
   Using default temp DH parameters
   Using default temp ECDH parameters
   ACCEPT

While this is running, use another terminal to start the client, and
you'll see the handshake complete if all certs/keys are correct:

   $ openssl s_client -connect localhost:1234 \
       -cert worker.crt \
       -key worker.key \
       -CAfile ca.crt
   CONNECTED(00000003)
   depth=1 /C=US/ST=California/L=San Francisco/O=Sloppy CA Inc. - 
   We approve Anything without checking!/OU=IT/CN=somewhere.com/
   emailAddress=a@b.com
   verify return:1
   ...
   Certificate chain
   ...
   SSL-Session:
   Protocol  : TLSv1
   ...
   Verify return code: 0 (ok)

This technique is especially helpful if you use your application's own
client or server in combination with openssl's C<s_client> or C<s_server>.

For example, to test if the Pogo worker can connect to a SSL server,
start C<s_server> and then fire up a Pogo worker:

    my $worker = Pogo::Worker->new(
        dispatchers => [ "localhost:xxxx" ],
        ssl         => 1,
        ...
    );

which should succeed immediately or print verbose output in case something
goes wrong.

=head1 LICENSE

Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
imitations under the License.

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>
Ian Bettinger <ibettinger@yahoo.com>

Many thanks to the following folks for implementing the
original version of Pogo: 

Andrew Sloane <andy@a1k0n.net>, 
Michael Fischer <michael+pogo@dynamine.net>,
Nicholas Harteau <nrh@hep.cat>,
Nick Purvis <nep@noisetu.be>,
Robert Phan <robert.phan@gmail.com>,
Srini Singanallur <ssingan@yahoo.com>,
Yogesh Natarajan <yogesh_ny@yahoo.co.in>

