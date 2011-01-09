package AnyEvent::HTTPD::Util;
use common::sense;

require Exporter;
our @ISA = qw/Exporter/;

our @EXPORT = qw/parse_urlencoded url_unescape/;

=head1 NAME

AnyEvent::HTTPD::Util - Utility functions for AnyEvent::HTTPD

=head1 SYNOPSIS

=head1 DESCRIPTION

The functions in this package are not public.

=over 4

=cut

sub url_unescape {
   my ($val) = @_;
   $val =~ s/\+/\040/g;
   $val =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr (hex ($1))/eg;
   $val
}

sub parse_urlencoded {
   my ($cont) = @_;
   my (@pars) = split /[\&\;]/, $cont;
   $cont = {};

   for (@pars) {
      my ($name, $val) = split /=/, $_;
      $name = url_unescape ($name);
      $val  = url_unescape ($val);

      push @{$cont->{$name}}, [$val, ''];
   }
   $cont
}



=back

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

