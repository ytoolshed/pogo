ServerRoot [% server_root %]
Listen [% httpd_port %]

LoadModule mime_module [% include_root %]/modules/mod_mime.so
LoadModule perl_module [% include_root %]/modules/mod_perl.so

User [% httpd_user %]
Group [% httpd_group %]

ServerAdmin [% httpd_user %]@localhost

DocumentRoot [% document_root %]

ErrorLog [% server_root %]/logs/error_log
LogLevel warn

DefaultType text/plain

PerlSwitches -I[% perl_lib %]

<Location /pogo>
  SetHandler perl-script
  PerlResponseHandler Pogo::UI
  PerlOptions +GlobalRequest
  PerlSetVar TEMPLATE_PATH [% template_dir %]
  PerlSetVar BASE_CGI_PATH /pogo
</Location>
