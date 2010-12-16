ServerRoot [% server_root %]
Listen [% httpd_port %]
PidFile [% log_dir %]/httpd.pid

LoadModule mime_module [% include_root %]/modules/mod_mime.so
LoadModule perl_module [% include_root %]/modules/mod_perl.so

User [% httpd_user %]
Group [% httpd_group %]

ServerAdmin [% httpd_user %]@localhost

DocumentRoot [% document_root %]

ErrorLog [% log_dir %]/error_log
LogLevel warn

DefaultType text/plain

PerlSwitches -I[% perl_lib %]

<Location /pogo-ui>
  SetHandler perl-script
  PerlResponseHandler Pogo::UI
  PerlOptions +GlobalRequest
  PerlSetVar POGO_API http://localhost:[% httpd_port %]/pogo/api/v3
  PerlSetVar TEMPLATE_PATH [% template_dir %]
  PerlSetVar BASE_CGI_PATH /pogo-ui
  PerlSetVar SHOW_LOGGER 1
</Location>

<Location /pogo>
  SetHandler perl-script
  PerlResponseHandler Pogo::API
  PerlOptions +GlobalRequest
  PerlSetVar POGO_CONFIG_DIR [% config_dir %]
</Location>
