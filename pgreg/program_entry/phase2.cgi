#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser); 
use HTML::Template;
use pgreglib;

my $cgi = CGI->new;

# セッションID = urlパラメータ||cookieからCGISESSID||取得できなかったらundef．
my $sid=$cgi->param('ID')||$cgi->cookie('ID')||undef;
my $session=CGI::Session->new(undef,$sid,{Directory=>'/tmp'});
my $input_page;
my $http_header;

if(defined $sid && $sid eq $session->id){
    # 取得したセッションidが有効:確認画面表示
    $input_page=HTML::Template->new(filename => 'phase2-tmpl.html');
	$session->param('phase', '2-1');

    # テンプレートにパラメータを設定
    pgreglib::pg_HtmlTmpl_set($input_page, $session, undef);
	$http_header = $cgi->header(-charset=>'UTF-8', -expires=>'now');
} else{
    # 古いセッションを削除
	if(defined $sid && $sid ne $session->id){
		  $session->close;
		  $session->delete;
	}
    # 取得したセッションidが無効:エラー画面表示
    $input_page=HTML::Template->new(filename => 'error-tmpl.html');
	$http_header = $cgi->header(-charset=>'UTF-8');
}
# 共通のTMPL変数置き換え
pgreglib::pg_stdHtmlTmpl_set($input_page, $sid);

print $http_header;
print "\n\n";
print $input_page->output;

exit;

1;
#end
