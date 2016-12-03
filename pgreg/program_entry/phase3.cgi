#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser); 
use HTML::Template;
use Data::Dumper;
use Encode qw/ decode /;
use JSON;
use MIME::Base64;
use pgreglib;
use LWP::UserAgent;
use IO::Socket::SSL qw/SSL_VERIFY_NONE/;
use HTTP::Request::Common;
use Try::Tiny;

my $cgi=CGI->new;

# セッションID = urlパラメータ||cookieからCGISESSID||取得できなかったらundef．
my $sid=$cgi->param('ID')||$cgi->cookie('ID')||undef;
my $session=CGI::Session->new(undef,$sid,{Directory=>'/tmp'});

my $input_page;

try {
    if(defined $sid && $sid eq $session->id){
        # 企画登録情報ハッシュ生成 (企画番号はundef)
        my $pHreg_param = pgreglib::pg_createRegParam($session, undef);

        # 企画登録実行(conkan企画登録WebAPI呼び出し)
        #  この中で、$pHreg_param->{'企画ID'}を設定
        #  戻り値は、( 内部企画ID, 企画番号 )
        my ( $pgid, $prog_no ) = _progRegViaConkanWebIF( $pHreg_param );
        $session->param( 'prog_no', $prog_no );

        # 登録者に送るmail生成/送付
        my $name = $session->param('p1_name');
        my $mailaddr = $session->param('email');
        my $mail_out = HTML::Template->new(filename => 'mail-finish-tmpl.txt');
        pgreglib::pg_stdMailTmpl_set( $mail_out, $mailaddr, $name );
        pgreglib::pg_HtmlTmpl_set($mail_out, $session, 1);
        my $mbody = $mail_out->output;
        pgreglib::doMailSend( $CONDEF_CONST{'ENVFROM'},
                    [ $mailaddr, $CONDEF_CONST{'ENTADDR'}, ],
                    $mbody )
            unless ( $session->param('dbgflgs')->{'NOMAIL2U'} );

        # 企画登録スタッフに送るメールの作成/送付
        $name = undef;
        $mailaddr = $CONDEF_CONST{'PGSTAFF'};
        $mail_out = HTML::Template->new(filename => 'mail-regist-tmpl.txt');
        pgreglib::pg_stdMailTmpl_set( $mail_out, $mailaddr, $name );
        $mail_out->param(BOUNDER    => '_REGPRM_' . $sid . '_');
        $mail_out->param(PGNO       => $pgid);
        $mail_out->param(MIMEPGSG   => $CONDEF_CONST{'MIMEPGSG'});
        $Data::Dumper::Terse = 1; # 変数名を表示しないおまじない
        $mail_out->param(REGPRM_DUMP  => Dumper($pHreg_param));
        $mail_out->param(JSON_FNAME   => 'reg_' . $pgid . '.json');
        my $jsonbody = decode('utf8', encode_json($pHreg_param));
        $mail_out->param(REGPRM_JSON  => encode_base64($jsonbody) );
        my $mbody2 = $mail_out->output;
        pgreglib::doMailSend( $CONDEF_CONST{'ENVFROM'},
                    [ $mailaddr, ],
                    $mbody2 )
            unless ( $session->param('dbgflgs')->{'NOMAIL2K'} );
    
        # HTMLを生成する。
        $input_page=HTML::Template->new(filename => 'phase3-tmpl.html');
        $input_page->param( 'phase3' => 1 );
        # phase3の戻りページでは企画番号を表示する
        pgreglib::pg_HtmlTmpl_set($input_page, $session, undef);

        if ( $session->param('dbgflgs')->{'SHOWMAIL2'} ) {
            pgreglib::pg_HtmlMailChk_set($input_page, $mbody, $mbody2);
        }
        if ( $session->param('dbgflgs')->{'SHOWJSON'} ) {
            my $jsontext = to_json($pHreg_param, {pretty => 1});
            pgreglib::pg_HtmlJson_set( $input_page, $jsontext );
        }

        # 全処理が完了したのでセッションを削除
        $session->close;
        $session->delete;

    }else{
        # 取得したセッションidが無効
        # 古いセッションを削除
        if(defined $sid && $sid ne $session->id){
            $session->close;
            $session->delete;
        }
        # エラー画面表示
        $input_page=HTML::Template->new(filename => 'error-tmpl.html');
    }
} catch {
    # システムエラー時セッションを削除
    $session->close;
    $session->delete;
    # エラー画面表示
    $input_page = HTML::Template->new(filename => 'regerr-tmpl.html');
    $input_page->param( 'catcherr' => $_ );
};

# 共通のTMPL変数置き換え
pgreglib::pg_stdHtmlTmpl_set( $input_page, $sid );

print $cgi->header(-charset=>'UTF-8', -expires=>'now');
print "\n\n";
print $input_page->output;

exit;

# 企画登録実行(conkan企画登録WebAPI呼び出し)
#  戻り値: 企画番号
#  エラー発生時 die
sub _progRegViaConkanWebIF {
    my (
        $pHreg_param,   # 企画登録情報ハッシュ
    ) = @_;

    my $pgid;
    my $prog_no;

    if ( $session->param('dbgflgs')->{'SKIPREGIST'} ) {
        # 登録スキップ時は、必要なもの(ダミー)のみ設定して戻る
        $pgid = 99;
        $prog_no = 9999;
        $pHreg_param->{'企画ID'} = $prog_no;
        return ( $pgid, $prog_no );
    };

    my $paramjson =  decode('utf8', encode_json($pHreg_param));
    my $req;
    my $res;
    my $session;

    # LWPエージェント生成(自己証明書対応)
    my $agent = LWP::UserAgent->new(
        ssl_opts => {
            verify_hostname => 0,
            SSL_verify_mode => SSL_VERIFY_NONE,
        }
    );
    $agent->cookie_jar( {} ); # Cookieを利用

    # adminでlogin -> RESPONCEは捨てる
    #   $CONDEF_CONST{'CONKANURL'} ,
    $req = POST( $CONDEF_CONST{'CONKANURL'} . 'login',
                 [  'realm'     => 'passwd',
                    'account'   => 'admin',
                    'passwd'    => $CONDEF_CONST{'CONKANPASS'},
                 ] );
    $res = $agent->request( $req );
    die 'login error: ' . $res->message if $res->is_error();
    
    # 企画登録
    $req = POST( $CONDEF_CONST{'CONKANURL'} . 'program/add',
                 Content_Type => 'form-data',
                 Content      =>
                    [
                        'jsoninputfile' =>
                            [
                                undef,
                                'regprog.json',
                                'Content-Type' => 'application/octet-stream',
                                'Content'      => $paramjson,
                            ]
                    ] );
    $res = $agent->request( $req );
    die 'program/add error: ' . $res->message if $res->is_error();
    
    # RESPONCEから内部企画IDと企画IDを取り出す
    #   (<a href="/program/[pgid]&amp;prog_id=[prog_no]">)
    if ( $res->content =~ m'<a href="/program/(\d+)&amp;prog_id=(\d+)">'m ) {
        $pgid = $1;
        $prog_no = $2;
        $pHreg_param->{'企画ID'} = $prog_no;
    }
    else {
        die 'Cannot get pgid or prog_no';
    }

    # logout
    $agent->get( $CONDEF_CONST{'CONKANURL'} . 'logout');
    # logoutはエラーになっても無視

    $agent = undef;
    return ( $pgid, $prog_no );
}

exit;

1;
#end
