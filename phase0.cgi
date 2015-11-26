#!/usr/bin/perl
# 企画申込フェーズ０
#
use lib ((getpwuid($<))[7]) . '/local/lib/perl5';
use strict;
use warnings;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser); 
use HTML::Template;
use File::Basename;
use pgreglib;
our %CONDEF_CONST;

# CGIパラメータ取得
my $cgi = CGI->new;
my $name     = $cgi->param("name"); 
my $mailaddr = $cgi->param("mail");
my $reg_num  = $cgi->param("reg_num"); 

# セッション生成
my $session;
$session=CGI::Session->new(undef,undef,{Directory=>'/tmp'});
$session->expire('+720m');              # 有効期限の設定．１２時間
# セッション経由で引き渡す項目と値
$session->param('reg_num',  $reg_num);  # 登録番号
$session->param('email',    $mailaddr); # メールアドレス
$session->param('p1_name',  $name);     # 申込者名
$session->param('phase','1-1');         # フェーズ番号

# 申し込みURL生成
my ($filename, $pathname) = fileparse($cgi->self_url);
$pathname =~ s/^http:/https:/g      # 開発環境ではhttpのまま
    unless $CONDEF_CONST{'DEVENV'};
my $next_uri = $pathname . 'phase1.cgi?ID=' . $session->id;

# テスト用(申し込みURL送信省略)
if (   ($reg_num eq $CONDEF_CONST{'SPREGNUM1'})
    || ($reg_num eq $CONDEF_CONST{'SPREGNUM2'}) ) {
	print $cgi->redirect($next_uri);
	exit(0);
}

# mail本文の生成/送信
my $mail_out = HTML::Template->new(filename => 'mail-first-tmpl.txt');
pgreglib::pg_stdMailTmpl_set( $mail_out, $mailaddr, $name );
$mail_out->param(URI => $next_uri);
my $mbody = $mail_out->output;
pgreglib::doMailSend( $CONDEF_CONST{'ENVFROM'}, [ $mailaddr, ], $mbody );

#htmlの生成/返却
my $page = HTML::Template->new(filename => 'phase0-tmpl.html');
pgreglib::pg_stdHtmlTmpl_set($page, $session->id);
if ( $reg_num eq $CONDEF_CONST{'SPREGNUM3'} ) {
    pgreglib::pg_HtmlMailChk_set($page, $mbody, undef );
}
print $cgi->header(-charset=>'UTF-8');
print "\n\n";
print $page->output;

exit;

1;
#end
