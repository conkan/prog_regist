#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser); 
use HTML::Template;
use HTML::FillInForm;
use pgreglib;

my $cgi=CGI->new;

# セッションID = urlパラメータ||cookieからCGISESSID||取得できなかったらundef．
my $sid=$cgi->param('ID')||$cgi->cookie('ID')||undef;
#セッションIDに基づきセッション取得 セッションIDが無効なら新たに発行
my $session=CGI::Session->new(undef,$sid,{Directory=>'/tmp'});

# 画面表示前処理
my $input_page  = undef; # HTML表示テンプレート
my $fobject     = undef; # HTML FormFillパラメータ
my $html_out    = undef; # 出力するHTML
my $http_header = $cgi->header( -charset => 'UTF-8', );

if ( $CONDEF_CONST{'ONLYUICHK'} || # UIチェック環境か
    ( defined $sid && $sid eq $session->id ) ) { # 取得したセッションidが有効
    # 申し込み画面 or 確認画面表示準備
    $input_page = HTML::Template->new(filename => 'phase1-tmpl.html');
    if( $session->param('phase') ne '1-2' ||
        !defined($cgi->param('self'))     ||
        $cgi->param('self') ne 'true' ) {
        # 申し込み画面初期表示準備
        $session->param('phase','1-2');
        $fobject    = $session;
    } else {
        # 申し込み受付時チェック
        if ( !( $session->param('dbgflgs')->{'SKIPVALID'} )
          && ( pgreglib::pg_input_check( $cgi ) ) ) {
            # 入力内容不備時 申込画面再表示準備
            $fobject    = $cgi;
        } else {
            # チェック成功 -> 入力値をセッションに保存し、phase2にredirect
            $cgi->param('dbgflgs', $session->param('dbgflgs'));
            $session->clear();
            my $sv = $CGI::LIST_CONTEXT_WARN;   # CGI::Sessionのエラー対応
            $CGI::LIST_CONTEXT_WARN = 0;        #   :
            $session->save_param($cgi);
            $CGI::LIST_CONTEXT_WARN = $sv;      #   :
            my $wkid = defined($cgi->cookie('ID')) ? $cgi->cookie('ID') : '';
            my $urlparam = ( $wkid eq  $session->id ) ? '' : '?ID=' . $sid;
            $input_page = undef;
            $html_out = $cgi->redirect('./phase2.cgi' . $urlparam);
        }
    }
} else {    # セッションタイムアウト
    # まずセッション開放
    if(defined $sid && $sid ne $session->id){
        $session->close;
        $session->delete;
    }
    # エラー画面表示準備
    $input_page = HTML::Template->new(filename => 'error-tmpl.html');
    my $cookie_path = $ENV{SCRIPT_NAME};
    $cookie_path =~ s/[^\/]+$//g ;
    my $cookie = $cgi->cookie(  -name => "ID",     -value => "$sid",
                                -expires => "+3h", -path => "$cookie_path");
    $http_header  = $cgi->header( -charset => 'UTF-8',
                                  -expires => 'now', -cookie => $cookie);
}

if ( $input_page ) { # リダイレクトではない
    # HTMLテンプレート変数置き換え
    pgreglib::pg_stdHtmlTmpl_set( $input_page, $sid );
    # パラメータをng-modelの初期値として登録
    pgreglib::pg_prmModelTmpl_set( $input_page, $fobject );
    
    $html_out = $input_page->output;
    # リダイレクトでない場合のみ、HTTPヘッダを出力
    print $http_header;
    print "\n\n";
}

# HTML本体出力
print $html_out;
exit;

1;
#end
