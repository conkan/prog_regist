#!/usr/bin/perl
use lib ((getpwuid($<))[7]) . '/local/lib/perl5';
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
our %CONDEF_CONST;

my $cgi=CGI->new;

# セッションID = urlパラメータ||cookieからCGISESSID||取得できなかったらundef．
my $sid=$cgi->param('ID')||$cgi->cookie('ID')||undef;
my $session=CGI::Session->new(undef,$sid,{Directory=>'/tmp'});

my $input_page;

### for develop
_progRegViaConkanWebIF ( { "申し込み日付" => "2015/02/13", "申込者名" => "宮崎恵彦", "メールアドレス" => "", "米魂番号" => "", "電話番号" => "", "FAX番号" => "", "携帯番号" => "", "企画名" => "テスト用ダミー", "企画名ふりがな" => "テストヨウダミー", "企画種別" => "その他", "企画種別その他内容" => "セレモニー", "希望場所" => "小ホール(300人)", "希望場所その他内容" => "", "希望レイアウト" => "シアター", "希望レイアウトその他内容" => "", "希望時刻" => "29日(土)午後", "希望時刻その他内容" => "", "希望コマ数" => "１コマ(90分+準備30分)", "希望コマ数その他内容" => "", "予想人数" => "200人超", "内容事前公開" => "事前公開可", "企画内容" => "星雲賞授与式です。", "リアルタイム公開" => "twitter等テキストと静止画公開可", "事後公開" => "blog等テキストと静止画公開可", "企画経験" => "継続して3～5回目", "重なると困る企画" => "", "備考" => "", "その他持ち込み機材" => "機材については未定。", "出演者氏名1" => "熊倉晃生", "出演者氏名ふりがな1" => "くまくらあきお", "出演交渉1" => "出演了承済", "ゲスト申請1" => "しない", "出演者氏名2" => "山本浩之", "出演者氏名ふりがな2" => "やまもとひろし", "出演交渉2" => "出演了承済", "ゲスト申請2" => "しない", "出演者氏名3" => "桑本 みつよし", "出演者氏名ふりがな3" => "くわもとみつよし", "出演交渉3" => "出演了承済", "ゲスト申請3" => "する"});

try {
    if(defined $sid && $sid eq $session->id){
        # 企画登録情報ハッシュ生成 (企画番号はundef)
        my $pHreg_param = pgreglib::pg_createRegParam($session, undef);

        # 企画登録実行(conkan企画登録WebAPI呼び出し)
        my $r_num = _progRegViaConkanWebIF( $pHreg_param );

        # 登録者に送るmail生成/送付
        my $name = $session->param('p1_name');
        my $mailaddr = $session->param('email');
        my $mail_out = HTML::Template->new(filename => 'mail-finish-tmpl.txt');
        pgreglib::pg_stdMailTmpl_set( $mail_out, $mailaddr, $name );
        pgreglib::pg_HtmlTmpl_set($mail_out, $session, 1);
        my $mbody = $mail_out->output;
        pgreglib::doMailSend( $CONDEF_CONST{'ENVFROM'},
                    [ $mailaddr, $CONDEF_CONST{'ENTADDR'}, ],
                    $mbody );

        # 企画登録スタッフに送るメールの作成/送付
        $name = undef;
        $mailaddr = $CONDEF_CONST{'PGSTAFF'};
        $mail_out = HTML::Template->new(filename => 'mail-regist-tmpl.txt');
        pgreglib::pg_stdMailTmpl_set( $mail_out, $mailaddr, $name );
        $mail_out->param(BOUNDER    => '_REGPRM_' . $sid . '_');
        $mail_out->param(PGNO       => $r_num);
        $mail_out->param(MIMEPGSG   => $CONDEF_CONST{'MIMEPGSG'});
        $Data::Dumper::Terse = 1; # 変数名を表示しないおまじない
        $mail_out->param(REGPRM_DUMP  => Dumper($pHreg_param));
        $mail_out->param(JSON_FNAME   => 'reg_' . $r_num . '.json');
        $mail_out->param(REGPRM_JSON  => encode_base64(decode('utf8', encode_json($pHreg_param))));
        my $mbody2 = $mail_out->output;
        pgreglib::doMailSend( $CONDEF_CONST{'ENVFROM'},
                    [ $mailaddr, ],
                    $mbody2 );
    
        # HTMLを生成する。
        $input_page=HTML::Template->new(filename => 'phase3-tmpl.html');
        pgreglib::pg_HtmlTmpl_set($input_page, $session, undef);
        if ( $session->param('reg_num') eq $CONDEF_CONST{'SPREGNUM2'}) {
            pgreglib::pg_HtmlMailChk_set($input_page, $mbody, $mbody2);
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
        $input_page=HTML::Template->new(filename => 'error.html');
    }
} catch {
    # システムエラー時セッションを削除
    $session->close;
    $session->delete;
    # エラー画面表示
    $input_page=HTML::Template->new(filename => 'regerr.html');
};

# 共通のTMPL変数置き換え
pgreglib::pg_stdHtmlTmpl_set( $input_page, $sid );

print $cgi->header(-charset=>'UTF-8', -expires=>'now');
print "\n\n";
print $input_page->output;

# 企画登録実行(conkan企画登録WebAPI呼び出し)
#  戻り値: 企画番号
#  エラー発生時 die
sub _progRegViaConkanWebIF {
    my (
        $pHreg_param,   # 企画登録情報ハッシュ
    ) = @_;

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
    die '' if $res->is_error();
    
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
    die '' if $res->is_error();
    
    # RESPONCEから企画番号($prog_no)を取り出す
    #   企画番号は リダイレクト先のパラメータ(<a href="/program/XXX">)
    my $prog_no = $1 if ( $res->content =~ m'<a href="/program/(\d+)">'m );
    die if ( $prog_no == undef );
    my $retval = sprintf( "%04d", $prog_no);

    # logout
    $agent->get( $CONDEF_CONST{'CONKANURL'} . 'logout');
    # logoutはエラーになっても無視

    $agent = undef;
    return $retval;
}

exit;

1;
#end
