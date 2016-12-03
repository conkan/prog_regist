#!/usr/bin/perl
# 企画申し込み入り口

use strict;
use warnings;
use CGI;
use HTML::Template;
use File::Basename;
use pgreglib;

#htmlの生成/返却
my $cgi = CGI->new;
my $tplname = $CONDEF_CONST{'MAINTENANCE'} ? 'index_maintenance-tmpl.html'
                                           : 'index_stable-tmpl.html';
my $page = HTML::Template->new(filename => $tplname );
pgreglib::pg_stdHtmlTmpl_set($page, undef);
print $cgi->header(-charset=>'UTF-8');
print "\n\n";
print $page->output;

exit;

1;
#end
