#!/usr/bin/perl
# 企画申込フェーズ０
#
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

# 登録番号からデバッグフラグを設定
my %debflg;
my @reg_dbg = split( ' ', $reg_num );
if ( ( 1 < scalar(@reg_dbg) ) &&
     ( $reg_dbg[1] eq $CONDEF_CONST{'SPPRIFIX'} ) ) {
    $reg_num = shift( @reg_dbg );
    shift( @reg_dbg );
    foreach my $dbgstr (@reg_dbg) {
        if ( $dbgstr eq $CONDEF_CONST{'NOURLMAIL'}) {
            $debflg{'NOURLMAIL'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'NOMAIL2U'}) {
            $debflg{'NOMAIL2U'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'NOMAIL2K'}) {
            $debflg{'NOMAIL2K'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'NOALLMAIL'}) {
            $debflg{'NOURLMAIL'} = 'true';
            $debflg{'NOMAIL2U'} = 'true';
            $debflg{'NOMAIL2K'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'SKIPVALID'}) {
            $debflg{'SKIPVALID'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'SKIPREGIST'}) {
            $debflg{'SKIPREGIST'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'SHOWUMAIL'}) {
            $debflg{'SHOWUMAIL'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'SHOWMAIL2'}) {
            $debflg{'SHOWMAIL2'} = 'true';
        }
        elsif ( $dbgstr eq $CONDEF_CONST{'SHOWJSON'}) {
            $debflg{'SHOWJSON'} = 'true';
        }
    }
}
if ($reg_num eq $CONDEF_CONST{'SPREGNUM1'}) {
    $debflg{'NOURLMAIL'} = 'true';
}
elsif ($reg_num eq $CONDEF_CONST{'SPREGNUM2'}) {
    $debflg{'NOURLMAIL'} = 'true';
    $debflg{'NOMAIL2U'}  = 'true';
    $debflg{'NOMAIL2K'}  = 'true';
    $debflg{'SHOWMAIL2'} = 'true';
}
elsif ($reg_num eq $CONDEF_CONST{'SPREGNUM3'}) {
    $debflg{'SHOWUMAIL'} = 'true';
}
if ( $CONDEF_CONST{'ONLYUICHK'} ) {
    $debflg{'NOURLMAIL'} = 'true';
    $debflg{'NOMAIL2U'}  = 'true';
    $debflg{'NOMAIL2K'}  = 'true';
    $debflg{'SKIPREGIST'} = 'true';
}

# セッション生成
my $session;
$session=CGI::Session->new(undef,undef,{Directory=>'/tmp'});
$session->expire('+720m');              # 有効期限の設定．１２時間
# セッション経由で引き渡す項目と値
$session->param('reg_num',  $reg_num);  # 登録番号
$session->param('email',    $mailaddr); # メールアドレス
$session->param('p1_name',  $name);     # 申込者名
$session->param('phase','1-1');         # フェーズ番号
$session->param('dbgflgs',  \%debflg);  # デバッグフラグ

# 申し込みURL生成
# referer()を元に生成するので、プロトコルの変更は不要
my ($filename, $pathname) = fileparse($cgi->referer());
my $next_uri = $pathname . 'phase1.cgi?ID=' . $session->id;

# テスト用(申し込みURL送信省略)
if ( $session->param('dbgflgs')->{'NOURLMAIL'} ) {
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
if ( $session->param('dbgflgs')->{'SHOWUMAIL'} ) {
    pgreglib::pg_HtmlMailChk_set($page, $mbody, undef );
}
print $cgi->header(-charset=>'UTF-8');
print "\n\n";
print $page->output;

exit;

1;
#end
