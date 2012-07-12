###########################################
package Pogo::One::Util;
###########################################
use warnings;
use strict;
use Exporter;
our @EXPORT_OK = qw( worker_cert worker_private_key );
our @ISA = qw( Exporter );

###########################################
sub worker_cert {
###########################################
      # THIS IS A TEST CERT, DO NOT USE IN PRODUCTION
    return <<'EOT';
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 2 (0x2)
        Signature Algorithm: md5WithRSAEncryption
        Issuer: C=US, ST=California, L=San Francisco, O=Sloppy CA Inc. - We approve Anything without checking!, OU=IT, CN=somewhere.com/emailAddress=a@b.com
        Validity
            Not Before: Mar  1 17:58:25 2012 GMT
            Not After : Mar  1 17:58:25 2013 GMT
        Subject: C=US, ST=California, O=Noname Inc., OU=IT, CN=worker-x.pogo.nonexist.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
            RSA Public Key: (1024 bit)
                Modulus (1024 bit):
                    00:9a:9e:2b:5f:1f:98:05:20:60:6e:07:3c:3e:5b:
                    8b:62:c4:0c:1e:f6:81:bb:13:d1:fc:e2:fe:65:f7:
                    9e:f1:e1:f8:e9:60:27:56:a9:8d:e6:ea:ca:62:a8:
                    c4:2a:a9:1a:a4:d5:a9:03:97:fb:be:1a:14:cf:00:
                    76:76:34:19:c5:16:a3:d5:d9:07:f6:b0:54:53:4e:
                    a0:45:11:0a:1f:06:c2:9a:c6:e7:31:fb:38:a6:91:
                    c2:2a:58:aa:c8:42:04:b9:80:3e:4c:7c:10:60:d6:
                    7e:76:de:87:73:81:62:e6:9b:ca:f0:e2:f6:d0:48:
                    d8:5a:aa:67:bb:96:e0:0b:bb
                Exponent: 65537 (0x10001)
    Signature Algorithm: md5WithRSAEncryption
        98:9c:52:53:91:ef:47:38:f3:c0:54:3f:01:3a:dd:ad:69:d3:
        5f:d2:cb:c0:ba:be:66:b5:88:a5:58:44:23:d2:cb:fc:67:bf:
        1c:6c:e5:b7:03:7f:99:23:8a:af:67:f8:c8:d7:48:9a:70:00:
        1b:ff:d2:4f:a2:3f:aa:b8:de:28:08:7b:cb:7f:50:46:31:df:
        70:0c:10:91:49:49:d3:76:1d:a6:00:49:38:c0:69:97:4f:3f:
        6e:b1:62:c1:02:0a:92:e2:cd:44:e1:2b:ec:d6:c6:b0:e4:77:
        4b:ca:c1:da:cf:f7:38:72:cf:ae:a1:2d:0e:aa:77:21:56:e1:
        45:df
-----BEGIN CERTIFICATE-----
MIICkjCCAfsCAQIwDQYJKoZIhvcNAQEEBQAwgbgxCzAJBgNVBAYTAlVTMRMwEQYD
VQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMT8wPQYDVQQK
FDZTbG9wcHkgQ0EgSW5jLiAtIFdlIGFwcHJvdmUgQW55dGhpbmcgd2l0aG91dCBj
aGVja2luZyExCzAJBgNVBAsTAklUMRYwFAYDVQQDEw1zb21ld2hlcmUuY29tMRYw
FAYJKoZIhvcNAQkBFgdhQGIuY29tMB4XDTEyMDMwMTE3NTgyNVoXDTEzMDMwMTE3
NTgyNVowajELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFDASBgNV
BAoTC05vbmFtZSBJbmMuMQswCQYDVQQLEwJJVDEjMCEGA1UEAxMad29ya2VyLXgu
cG9nby5ub25leGlzdC5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAJqe
K18fmAUgYG4HPD5bi2LEDB72gbsT0fzi/mX3nvHh+OlgJ1apjebqymKoxCqpGqTV
qQOX+74aFM8AdnY0GcUWo9XZB/awVFNOoEURCh8GwprG5zH7OKaRwipYqshCBLmA
Pkx8EGDWfnbeh3OBYuabyvDi9tBI2FqqZ7uW4Au7AgMBAAEwDQYJKoZIhvcNAQEE
BQADgYEAmJxSU5HvRzjzwFQ/ATrdrWnTX9LLwLq+ZrWIpVhEI9LL/Ge/HGzltwN/
mSOKr2f4yNdImnAAG//ST6I/qrjeKAh7y39QRjHfcAwQkUlJ03YdpgBJOMBpl08/
brFiwQIKkuLNROEr7NbGsOR3S8rB2s/3OHLPrqEtDqp3IVbhRd8=
-----END CERTIFICATE-----
EOT
}

###########################################
sub worker_private_key {
###########################################
      # THIS IS A TEST KEY, DO NOT USE IN PRODUCTION
    return <<'EOT';
-----BEGIN RSA PRIVATE KEY-----
MIICWwIBAAKBgQCanitfH5gFIGBuBzw+W4tixAwe9oG7E9H84v5l957x4fjpYCdW
qY3m6spiqMQqqRqk1akDl/u+GhTPAHZ2NBnFFqPV2Qf2sFRTTqBFEQofBsKaxucx
+zimkcIqWKrIQgS5gD5MfBBg1n523odzgWLmm8rw4vbQSNhaqme7luALuwIDAQAB
AoGAL4eDqaAaqSjEu835lOmrNVcyqqn4QzvahzR4I3w1HgHq9EKclSVV+7AdOqrK
cpq9GAKeC/7CYjO+RcvMnpVxfgwTdcGjy926EcoPlmDV2oEyQ9/FwJA0aeOu2CcA
+LPgDNoZtxyiP0lXUIYyJUy2GV4Bygudi6IMBy75dHOnzHECQQDMvQTv1H2o1Mzs
dFythyHx0MvCiSArp7246hM2Jtj/QJgnJzwh7xphpk2QwrWFBfe3tCqDLbiJcNyl
PncTQze/AkEAwVSb1OALF6McgU/qHI0wLU6o2BMkuD+iBAOTnentN4X7jgVvrWVc
kn7UyA3xNeI0pwDXb1Gnf0MvTH3UMYVLBQJAB1tneQLGvTFgZ8LKrcWkV58sI0Jw
MIFnlOR8aj69H3b/wLBtPb7s0MN8GA6XHT+YpjZILMyQzAeNNjbnan7I2wJAOUav
xCl8H8ybLVRXr43EsCeVri49urhfb4D/wtEDDmgLVtAVffGBs4UP1RUMWUJjBvcg
3EH8tZ9Z6/d7XhB3YQJAJWZr0CKU+Y87aYXptX8b3Jxj3j549roLgQQyWB90HItO
+mea8OdwMD+WUH9yHhdFS76sLCpHMvJ7EB8reRlGhQ==
-----END RSA PRIVATE KEY-----
EOT
}

1;

__END__

=head1 NAME

Pogo::One::Util - Utilities for Pogo One

=head1 DESCRIPTION

Some utilities like test worker certs and keys for Pogo::One.

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

=head1 AUTHOR

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

