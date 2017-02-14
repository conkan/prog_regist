#!/usr/bin/perl
package pgreglib;
use strict;
use warnings;

use pgregdef;
use regmail;

require Exporter;
use base qw/Exporter/;

our @EXPORT = qw(
    %CONDEF_CONST
    doMailSend
    _DEBUG_
);

our %EXPORT_TAGS = (
    default      => [ @EXPORT ],
);

### CONDEF_CONST初期値設定&矛盾チェック (動作上不具合になるもの)
$CONDEF_CONST{'MAXGCNT'}            ||= 8; 
$CONDEF_CONST{'SMTP'}->{'SERVER'}   ||= '127.0.0.1'; 
$CONDEF_CONST{'SMTP'}->{'PORT'}     ||= 25; 
die 'SMTP TLS must use SMTP AUTH'
    if ( $CONDEF_CONST{'SMTP'}->{'TLS'} && !$CONDEF_CONST{'SMTP'}->{'AUTH'} );
die 'SMTP AUTH must set SMTP AUTH_USER and AUTH_PASS'
    if ( $CONDEF_CONST{'SMTP'}->{'AUTH'} &&
         !( $CONDEF_CONST{'SMTP'}->{'AUTH_USER'} && 
            $CONDEF_CONST{'SMTP'}->{'AUTH_PASS'}    ) );
### HTMLテンプレート置き換え定義
# radiobox CGI値変換テーブル作成
my %pg_kind_cnv     = map { $_->{VAL} => $_->{DISP} } @pg_kind_ary;
my %pg_place_cnv    = map { $_->{VAL} => $_->{DISP} } @pg_place_ary;
my %pg_layout_cnv   = map { $_->{VAL} => $_->{DISP} } @pg_layout_ary;
my %pg_time_cnv     = map { $_->{VAL} => $_->{DISP} } @pg_time_ary;
my %pg_koma_cnv     = map { $_->{VAL} => $_->{DISP} } @pg_koma_ary;
my %pg_ninzu_cnv    = map { $_->{VAL} => $_->{DISP} } @pg_ninzu_ary;
my %pg_kafuka_cnv   = map { $_->{VAL} => $_->{DISP} } @pg_kafuka_ary;
my %pg_naiyou_k_cnv = map { $_->{VAL} => $_->{DISP} } @pg_naiyou_k_ary;
my %pg_kiroku_cnv   = map { $_->{VAL} => $_->{DISP} } @pg_kiroku_ary;
my %motikomi_cnv    = map { $_->{VAL} => $_->{DISP} } @motikomi_ary;
my %av_v_cnv        = map { $_->{VAL} => $_->{DISP} } @av_v_ary;
my %av_a_cnv        = map { $_->{VAL} => $_->{DISP} } @av_a_ary;
my %pc_v_cnv        = map { $_->{VAL} => $_->{DISP} } @pc_v_ary;
my %pc_a_cnv        = map { $_->{VAL} => $_->{DISP} } @pc_a_ary;
my %lan_cnv         = map { $_->{VAL} => $_->{DISP} } @lan_ary;
my %pg_enquete_cnv  = map { $_->{VAL} => $_->{DISP} } @pg_enquete_ary;
my %ppn_youdo_cnv   = map { $_->{VAL} => $_->{DISP} } @ppn_youdo_ary;
my %ppn_con_cnv     = map { $_->{VAL} => $_->{DISP} } @ppn_con_ary;
my %ppn_grq_cnv     = map { $_->{VAL} => $_->{DISP} } @ppn_grq_ary;

# 単純置き換え パラメータ名配列
my @org_pname = (
    'p1_name', 'email', 'reg_num', 'tel', 'fax', 'cellphone', 'phonetime',
    'prog_no', 'pg_name', 'pg_name_f', 'pg_naiyou', 'fc_other_naiyou',
    'fc_mochikomi', 'pg_badprog', 'py_name', 'py_name_f', 'py_title', 'pp_cnt',
    'fc_comment',
);

# テーブル変換 パラメータテーブル
#   key: パラメータ名
#   value[0]:変換テーブル
#   value[1]:その他内容パラメータ名
my %tbl_pname = (
    'pg_kind'       => [ \%pg_kind_cnv,         'pg_kind2', ],
    'pg_place'      => [ \%pg_place_cnv,        'pg_place2', ],
    'pg_layout'     => [ \%pg_layout_cnv,       'pg_layout2', ],
    'pg_time'       => [ \%pg_time_cnv,         'pg_time2', ],
    'pg_koma'       => [ \%pg_koma_cnv,         'pg_koma2', ],
    'pg_ninzu'      => [ \%pg_ninzu_cnv,        undef, ],
    'pg_pgu18'      => [ \%pg_kafuka_cnv,       undef, ],
    'pg_pggen'      => [ \%pg_kafuka_cnv,       undef, ],
    'pg_naiyou_k'   => [ \%pg_naiyou_k_cnv,     undef, ],
    'pg_kiroku_kb'  => [ \%pg_kiroku_cnv,       undef, ],
    'pg_kiroku_ka'  => [ \%pg_kiroku_cnv,       undef, ],
    'pg_enquete'    => [ \%pg_enquete_cnv,      undef, ],
);
# 使用する/しない パラメータテーブル
#   key: パラメータ名
#   value: 本数パラメータ名
my %useunuse_pname = (
    'wbd'   =>  undef,
    'mic'   =>  'miccnt',
    'mic2'  =>  'mic2cnt',
    'mon'   =>  undef,
    'dvd'   =>  undef,
    'syo'   =>  undef,
);

# 持ち込む/持ち込まない パラメータテーブル
#   key: パラメータ名
#   value: パラメータテーブル配列 av機器とpcで表示を揃えるため配列化
#       配列の中身は連想配列(1要素)
#           pname : パラメータ名
#           value : 追加情報配列
#               value[0]:変換テーブル
#               value[1]:その他内容パラメータ名
#               value[2]:注釈
my %motikomi_pname = (
    'fc_vid'    => [
        { pname => 'av-v',
          value  => [ \%av_v_cnv,    'av-v_velse',   '映像接続', ], },
        { pname => 'av-a',
          value  => [ \%av_a_cnv,    'av-a_velse',   '音声接続', ], },
    ],
    'fc_pc'     => [
        { pname => 'pc-v',
          value  => [ \%pc_v_cnv,    'pc-v_velse',   '映像接続', ], },
        { pname => 'pc-a',
          value  => [ \%pc_a_cnv,    'pc-a_velse',   '音声接続', ], },
    ],
);

# ネット接続テーブル変換 パラメータテーブル
#   PC持ち込み時のみ変換するため、別テーブルとする
#   key: パラメータ名
#   value[0]:変換テーブル
#   value[1]:その他内容パラメータ名
my %lan_pname = (
    'lan'   => [ \%lan_cnv, 'pc-l_velse', ],
);

# 登録画面全パラメータ名
#   一部はテーブルの値にも定義があるが、煩雑なので直接指定
my @all_pname = (
    @org_pname,
    keys( %tbl_pname ),
    keys( %useunuse_pname ),
    keys( %motikomi_pname ),
    keys( %lan_pname ),
    'pg_kind2', 'pg_place2', 'pg_layout2', 'pg_time2', 'pg_koma2',
    'miccnt', 'mic2cnt', 'av-v', 'av-v_velse', 'av-a', 'av-a_velse',
    'pc-v', 'pc-v_velse', 'pc-a', 'pc-a_velse', 'pc-l_velse', 'lanreason',
    'youdo', );

##############################################################################
# テンプレート処理共通関数
##############################################################################

# 共通関数 CONDEF_CONST テンプレート変数設定
sub pg_stdConstTmpl_set {
    my (
        $page,  # HTML::Templateオブジェクト
    ) = @_;

    foreach my $name ( keys(%CONDEF_CONST) ) {
        $page->param($name => $CONDEF_CONST{$name}) 
            if ( $page->query(name => $name));
    }
}

# 共通関数 HTMLテンプレート共通変数設定
sub pg_stdHtmlTmpl_set {
    my (
        $page,  # HTML::Templateオブジェクト
        $sid,   # セッションID
    ) = @_;

    pg_stdConstTmpl_set($page);
    $page->param(ID => $sid) if ( $page->query(name => 'ID'));
}

# 共通関数 MailBodyテンプレート共通変数設定
sub pg_stdMailTmpl_set {
    my (
        $page,      # HTML::Templateオブジェクト
        $toaddr,    # MailHeader:To
        $name,      # MailBody:申込者名
    ) = @_;
    pg_stdConstTmpl_set($page);
    $page->param(TOADDR => $toaddr) if ( $page->query(name => 'TOADDR') );
    $page->param(NAME   => $name) if ( $page->query(name => 'NAME') );
}

# 共通関数 設定値確認テンプレート変数設定
sub pg_HtmlTmpl_set {
    my (
        $page,  # HTML::Templateオブジェクト
        $sprm,  # CGI::Sessionオブジェクト
        $isMail,    # undef:HTML用 その他:Mail用
    ) = @_;

    my $pname;
    my $pAprm;

    # 単純置き換え
    foreach $pname ( @org_pname ) {
        my $value = $sprm->param($pname);
        $value =~ s/[\r\n]+/<br\/>/mg
            if defined($value) && !defined($isMail);
        $page->param( $pname => $value )
            if ( $page->query(name => $pname) );
    }
    # テーブル変換(その他解釈込み)
    while ( ($pname, $pAprm) = each %tbl_pname ) {
        $page->param( $pname => cnv_radio_val($sprm, $pname, $pAprm ))
            if ( $page->query(name => $pname) );
    }
    # 使用する/しない(本数解釈込み)
    while ( ($pname, $pAprm) = each %useunuse_pname ) {
        $page->param( $pname => cnv_useunuse_val($sprm, $pname, $pAprm))
            if ( $page->query(name => $pname) );
    }

    my $add0 = $isMail ? "\n      利用方法:" : '<br/><b>利用方法</b>';
    my $add1 = $isMail ? "\n      " : '<div class="indent">';
    my $add2 = $isMail ? ''     : '</div>';

    # 持ち込む/持ち込まない(追加項目解釈込み)
    while ( ($pname, $pAprm) = each %motikomi_pname ) {
        my $value = $motikomi_cnv{$sprm->param($pname)};
        if ( $value eq '持ち込む' ) {
            foreach my $ri ( @$pAprm ) {
                my $pn2 = $ri->{pname};
                my $pAp2 = $ri->{value};
                $value .= $add1
                        . $pAp2->[2] . ':'
                        . cnv_radio_val($sprm, $pn2, $pAp2)
                        . $add2;
            }
        }
        $page->param( $pname => $value )
            if ( $page->query(name => $pname) );
    }
    # ネット接続に関する特殊処理
    if ( $motikomi_cnv{$sprm->param('fc_pc')} eq '持ち込む' ) {
        while ( ($pname, $pAprm) = each %lan_pname ) {
            my $value = cnv_radio_val($sprm, $pname, $pAprm);
            if ( $value ne '接続しない' ) {
                $value .= $add0 . $add1
                        . $sprm->param('lanreason')
                        . $add2;
            }
            $value =~ s/[\r\n]+/<br\/>/mg
                unless $isMail;
            $page->param( $pname => $value )
                if ( $page->query(name => $pname) );
        }
    }

    # 申込者出演情報
    $page->param( 'youdo' => $ppn_youdo_cnv{$sprm->param('youdo')} )
        if ( $page->query(name => 'youdo') );
    # 出演者情報(LOOP)
    my @loop_data = ();  # TMPL変数名=>値ハッシュ参照 の配列
    my $ppcnt;
    my $ppmax = $CONDEF_CONST{'MAXGCNT'};   # CONST: 出演者の最大値
    for ($ppcnt = 1; $ppcnt <= $ppmax; $ppcnt++) {
        my $prefix = 'pp' . $ppcnt;
        my $ppname = $sprm->param($prefix . '_name');
        if ( defined($ppname) && $ppname  ne '') {
            my %row_data;
            $row_data{'pp_number'}  = $ppcnt;
            $row_data{'pp_name'}    = $ppname;
            $row_data{'pp_name_f'}  = $sprm->param($prefix . '_name_f');
            $row_data{'pp_title'}   = $sprm->param($prefix . '_title');
            $row_data{'pp_con'} = $ppn_con_cnv{$sprm->param($prefix . '_con')};
            $row_data{'pp_grq'} = $ppn_grq_cnv{$sprm->param($prefix . '_grq')};
            push(@loop_data, \%row_data);
        }
    }
    $page->param(GUEST_LOOP => \@loop_data)
        if ( $page->query(name => 'GUEST_LOOP') );
}

# テーブル変換(その他解釈込み)
sub cnv_radio_val {
    my (
        $sprm,      # CGI::Sessionオブジェクト
        $pname,     # パラメータ名
        $pAprm,     # 追加情報 [0]:変換テーブル [1]:その他内容パラメータ名
    ) = @_;

    my $value = $pAprm->[0]->{$sprm->param($pname)};
    if ( defined( $pAprm->[1] ) and ( $value eq 'その他' ) ) {
        $value .= '(' . $sprm->param($pAprm->[1]) . ')';
    }
    return ($value);
}

# 使用する/しない(本数解釈込み)
sub cnv_useunuse_val {
    my (
        $sprm,      # CGI::Sessionオブジェクト
        $pname,     # パラメータ名
        $opname,    # 追加情報パラメータ名 undef:なし
    ) = @_;

    my $value = $sprm->param($pname) ? '使用する' : '使用しない';
    if ( $opname && ( $value eq '使用する' ) ) {
        $value .= ' (' . $sprm->param($opname) . '本)';
    }
    return ($value);
}

# 共通関数 企画登録画面テンプレートパラメータ設定
sub pg_prmModelTmpl_set {
    my (
        $page,  # HTML::Templateオブジェクト
        $obj,   # CGIオブジェクト/CGI::Sessionオブジェクト
     ) = @_;

    # @all_pname に定義されているパラメータの値設定
    foreach my $pname ( @all_pname ) {
        if ( ( $page->query(name => $pname) ) &&
             ( defined($obj->param($pname)) )     ) {
            $page->param($pname   => $obj->param($pname));
        }
    }
    # radiobox選択肢生成
    $page->param(KIND_LOOP => \@pg_kind_ary)
        if ( $page->query(name => 'KIND_LOOP') );
    $page->param(PLACE_LOOP => \@pg_place_ary)
        if ( $page->query(name => 'PLACE_LOOP') );
    $page->param(LAYOUT_LOOP => \@pg_layout_ary)
        if ( $page->query(name => 'LAYOUT_LOOP') );
    $page->param(TIME_LOOP => \@pg_time_ary)
        if ( $page->query(name => 'TIME_LOOP') );
    $page->param(KOMA_LOOP => \@pg_koma_ary)
        if ( $page->query(name => 'KOMA_LOOP') );
    $page->param(NINZU_LOOP => \@pg_ninzu_ary)
        if ( $page->query(name => 'NINZU_LOOP') );
    $page->param(KAFUKA_LOOP => \@pg_kafuka_ary)
        if ( $page->query(name => 'KAFUKA_LOOP') );
    $page->param(NAIYOUK_LOOP => \@pg_naiyou_k_ary)
        if ( $page->query(name => 'NAIYOUK_LOOP') );
    $page->param(KIROKU_LOOP => \@pg_kiroku_ary)
        if ( $page->query(name => 'KIROKU_LOOP') );
    $page->param(MOTIKOMI_LOOP => \@motikomi_ary)
        if ( $page->query(name => 'MOTIKOMI_LOOP') );
    $page->param(AV_V_LOOP => \@av_v_ary)
        if ( $page->query(name => 'AV_V_LOOP') );
    $page->param(AV_A_LOOP => \@av_a_ary)
        if ( $page->query(name => 'AV_A_LOOP') );
    $page->param(PC_V_LOOP => \@pc_v_ary)
        if ( $page->query(name => 'PC_V_LOOP') );
    $page->param(PC_A_LOOP => \@pc_a_ary)
        if ( $page->query(name => 'PC_A_LOOP') );
    $page->param(LAN_LOOP => \@lan_ary)
        if ( $page->query(name => 'LAN_LOOP') );
    $page->param(ENQUETE_LOOP => \@pg_enquete_ary)
        if ( $page->query(name => 'ENQUETE_LOOP') );
    $page->param(YOUDO_LOOP => \@ppn_youdo_ary)
        if ( $page->query(name => 'YOUDO_LOOP') );

    # 出演者情報(LOOP)
    my @loop_data = ();  # TMPL変数名=>値ハッシュ参照 の配列
    my $ppcnt;
    my $ppmax = $CONDEF_CONST{'MAXGCNT'};   # CONST: 出演者の最大値
    for ($ppcnt = 1; $ppcnt <= $ppmax; $ppcnt++) {
        my %row_data;
        my $ppno = $ppcnt - 1;
        my $prefix = 'pp' . $ppcnt;
        # 名前が未定義なら次
        next unless $obj->param($prefix . '_name');
        $row_data{'pp_no'}      = $ppno;
        $row_data{'pp_number'}  = $ppcnt;
        $row_data{'mod_pre'}    = 'pgrg.ppGuest[' . $ppno . ']';
        $row_data{'mod_name'}   = 'pgrg.ppGuest[' . $ppno . '].name';
        $row_data{'mod_con'}    = 'pgrg.ppGuest[' . $ppno . '].con';
        $row_data{'mod_grq'}    = 'pgrg.ppGuest[' . $ppno . '].grq';
        $row_data{'id_pre'}     = $prefix;
        $row_data{'id_con'}     = $prefix . '_con';
        $row_data{'id_grq'}     = $prefix . '_grq';
        $row_data{'pp_name'}    = $obj->param($prefix . '_name');
        $row_data{'pp_name_f'}  = $obj->param($prefix . '_name_f');
        $row_data{'pp_title'}   = $obj->param($prefix . '_title');
        $row_data{'pp_con'}     = $obj->param($prefix . '_con');
        $row_data{'pp_grq'}     = $obj->param($prefix . '_grq');
        $row_data{'CON_LOOP'}   = [
            map { { %$_,
                    'mod_name'  => $row_data{'mod_name'},
                    'pp_no'     => $row_data{'pp_no'},
                    'mod_con'   => $row_data{'mod_con'},
                    'id_con'    => $row_data{'id_con'},
                  }
                } @ppn_con_ary
            ];
        $row_data{'GRQ_LOOP'}   = [
            map { { %$_,
                    'mod_name'  => $row_data{'mod_name'},
                    'pp_no'     => $row_data{'pp_no'},
                    'mod_grq'   => $row_data{'mod_grq'},
                    'id_grq'    => $row_data{'id_grq'},
                  }
                } @ppn_grq_ary
            ];
        push(@loop_data, \%row_data);
    }
    $page->param(GUEST_LOOP => \@loop_data)
        if ( $page->query(name => 'GUEST_LOOP') );
}

##############################################################################
# 企画登録(WebAPIデータ作成)
##############################################################################
# 企画登録WebAPI連想配列生成用 ハッシュテーブル(基本)
#   key: パラメータ名
#   val: [0]:JSONキー名
#      : [1]:undef:値使用
#            Scalar:値追記対象 追記プレフィックス
#            HASHREF:変換テーブル   
#      : [2]:その他の場合の値パラメータ名
my %h_base_pname2json = (
    'prog_no'       => ['prog_no', undef, undef],
    # 申込者情報
    'p1_name'       => ['p1_name', undef, undef],
    'email'         => ['email', undef, undef],
    'reg_num'       => ['reg_num', undef, undef],
    'tel'           => ['tel', undef, undef],
    'fax'           => ['fax', undef, undef],
    'cellphone'     => ['cellphone', undef, undef],
    # 企画情報
    'pg_name'       => ['pg_name', undef, undef],
    'pg_name_f'     => ['pg_name_f', undef, undef],
    'pg_kind'       => ['pg_kind', \%pg_kind_cnv, 'pg_kind2'],
    'pg_place'      => ['pg_place', \%pg_place_cnv, 'pg_place2'],
    'pg_layout'     => ['pg_layout', \%pg_layout_cnv, 'pg_layout2'],
    'pg_time'       => ['pg_time', \%pg_time_cnv, 'pg_time2'],
    'pg_koma'       => ['pg_koma', \%pg_koma_cnv, 'pg_koma2'],
    'pg_ninzu'      => ['pg_ninzu', \%pg_ninzu_cnv, undef],
    'pg_pgu18'      => ['pg_pgu18', \%pg_kafuka_cnv, undef],
    'pg_pggen'      => ['pg_pggen',   \%pg_kafuka_cnv, undef],
    'pg_naiyou_k'   => ['pg_naiyou_k', \%pg_naiyou_k_cnv, undef],
    'pg_naiyou'     => ['pg_naiyou', undef, undef],
    'pg_kiroku_kb'  => ['pg_kiroku_kb', \%pg_kiroku_cnv, undef],
    'pg_kiroku_ka'  => ['pg_kiroku_ka', \%pg_kiroku_cnv, undef],
    # 企画経験
    'pg_enquete'    => ['pg_enquete', \%pg_enquete_cnv, undef],
    # 重なると困る企画
    'pg_badprog'    => ['pg_badprog', undef, undef],
    # 備考
    'fc_comment'    => ['fc_comment', undef, undef],
    'phonetime'     => ['fc_comment', ' 電話連絡可能な時間帯:', undef],
);


# 企画登録WebAPIパラメータ生成
#   戻り値: WebAPIデータオブジェクト参照
sub pg_createRegParam {
    my (
        $sprm,      # セッションオブジェクト(含企画パラメータ)
        $pg_num,    # 企画番号(4文字数字)
     ) = @_;

    my $preg_param;

    # APIバージョン設定
    $preg_param->{'WebAPI_VERSION'} = '2.0';
    # 登録日設定
    my($c_d, $c_m, $c_y) = (localtime(time))[3,4,5];
    $c_y += 1900;
    $c_m += 1;
    $preg_param->{'regdate'} = sprintf('%4d/%02d/%02d', $c_y, $c_m, $c_d);
    # (念のため) 企画番号指定=上書き登録
    $preg_param->{'prog_no'} = $pg_num if defined( $pg_num );

    # 基本情報生成
    # %h_base_pname2jsonの定義に従って値設定 
    while ( my ($pname, $pAval) = each(%h_base_pname2json)) {
        my $preg_item = pg_CnvPrgAPI( $sprm, $pname, $pAval );
        $preg_param = { %$preg_param, %$preg_item } if defined($preg_item);
    }

    # 機材情報生成
    my $pAequips = pg_CrtEquipReg( $sprm );
    $preg_param->{'equips'} = $pAequips if defined( $pAequips );

    # 出演者情報生成
    my $pAcasts = pg_CrtCastReg( $sprm );
    $preg_param->{'casts'} = $pAcasts if defined( $pAcasts );

    return($preg_param);
}

# 変換定義に従って指定HTMLパラメータに対応したWebAPIデータを返す
#   戻り値: WebAPIデータオブジェクト参照
sub pg_CnvPrgAPI {
    my (
        $sprm,      # セッションオブジェクト(含企画パラメータ)
        $pname,     # HTMLパラメータ名
        $pAval,     # 変換定義
                    #   : [0]:JSONキー名
                    #   : [1]:undef:値使用
                    #         Scalar:値追記対象 追記プレフィックス
                    #         HASHREF:変換テーブル   
                    #   : [2]:その他の場合の値パラメータ名
     ) = @_;

    my $preg_prm = {};
    my $key = $pAval->[0];
    my $val = $sprm->param($pname);
    # パラメータが設定されていない/空白 だったらundefを返す
    return(undef) unless ( defined( $val ) );
    return(undef) if ( $val eq '' );

    if ( !defined($pAval->[1]) ) {
        # 値自体
        $preg_prm->{$key} = $val;
    } elsif ( ref($pAval->[1]) eq 'HASH' ) {
        # 変換
        $preg_prm->{$key} = $pAval->[1]->{$val};
        if ( defined($pAval->[2]) ) {
            # その他の値設定
            if ( $val eq 'other' ) {
                $preg_prm->{$key} .= ' ' . $sprm->param($pAval->[2]);
            }
        }
    } else {
        # 追記
        $preg_prm->{$key} .= ' ' . $pAval->[1] . ' ' . $val;
    }
    return($preg_prm);
}

# 企画登録WebAPI連想配列生成用 ハッシュテーブル(機材)
#   key: パラメータ名
#   val: [0]:機材名 undef: 機材名として値を使う
#      : [1]:undef:  提供機材(on/offで判断)
#            scalar: 機材名につける注釈([0]がundefの時)
#            HASHREF:変換テーブル(持ち込みかどうかの判断のみに使用)
#      : [2]:undef: 追加情報なし
#            HASHREF:追加情報登録ハッシュテーブル
#               key: 追加情報パラメータ名
#               val: [0]:子階層JSONキー名
#                  : [1]:undef:値使用 HASHREF:変換テーブル   
#                  : [2]:その他の場合の値パラメータ名
my %h_equip_pname2json = (
    'wbd'    => ['ホワイトボード', undef, undef],
    'mic'    => ['壇上マイク', undef,
                 {
                     miccnt => ['count', undef, undef]
                 } ],
    'mic2'   => ['客席マイク', undef,
                 {
                     mic2cnt => ['count', undef, undef]
                 } ],
    'mon'    => ['モニタ/スクリーン', undef, undef],
    'dvd'    => ['BD/DVDプレイヤー', undef, undef],
    'syo'    => ['書画カメラ', undef, undef],
    'fc_vid' => ['持ち込み映像機器', \%motikomi_cnv,
                 {
                     'av-v'  => ['vif', \%av_v_cnv, 'av-v_velse' ],
                     'av-a'  => ['aif', \%av_a_cnv, 'av-a_velse' ],
                 } ],
    'fc_pc'  => ['持ち込みPC', \%motikomi_cnv,
                 {
                     'pc-v'  => ['vif', \%pc_v_cnv, 'pc-v_velse'],
                     'pc-a'  => ['aif', \%pc_a_cnv, 'pc-a_velse'],
                     'lan'   => ['eif', \%lan_cnv,  'pc-l_velse'],
                     'lanreason' => ['intende', undef, undef ],
                 } ],
    'fc_other_naiyou'   => [undef, '(要望)', undef],
    'fc_mochikomi'      => [undef, '(持ち込み)', undef],
);

# 機材情報生成
# %h_equip_pname2json の定義に従って配列作成
# 戻り値: 機材情報配列参照
sub pg_CrtEquipReg {
    my (
        $sprm,      # セッションオブジェクト(含企画パラメータ)
     ) = @_;

    my $pAequips = [];
    while ( my ($pname, $pAval) = each(%h_equip_pname2json)) {
        my $val = $sprm->param($pname);
        # パラメータが設定されていない/空白 だったら、次
        next unless ( defined( $val ) );
        next if ( $val eq '' );

        my $one_equip = {};
        if ( !defined($pAval->[0]) ) {
            # 機材名として値を使う
            $one_equip->{'name'} = $val . $pAval->[1];
        }
        elsif ( !defined($pAval->[1]) ) {
            # 機材名固定(提供分)
            if ( $val eq 'on' ) {
                $one_equip->{'name'} = $pAval->[0];
            }
        }
        elsif ( ref($pAval->[1]) eq 'HASH' ) {
            # 機材名固定(持ち込み分)
            if ( $val eq 'MT-0' ) {
                $one_equip->{'name'} = $pAval->[0];
            }
            else {
                next;   # 持ち込まないなら、次
            }
        }

        if ( defined($pAval->[2]) ) {
            # pAval->[2]は必ず変換定義HASH
            while ( my ($addpname, $pAaddval) = each( %{$pAval->[2]} )) {
                my $padd = pg_CnvPrgAPI( $sprm, $addpname, $pAaddval );
                $one_equip = { %$one_equip, %$padd } if defined( $padd );
            }
        }
        push ( @$pAequips, $one_equip );
    }
    return($pAequips);
}

my %h_cast_pname2json = (
    # 申込者出演情報
    'youdo'         => ['申込者出演', \%ppn_youdo_cnv],
    'py_name'       => ['申込者企画ネーム', undef],
    'py_name_f'     => ['申込者企画ネームフリガナ', undef],
    'py_title'      => ['申込者肩書', undef],
    # 出演者情報
    'pp_cnt'        => ['出演者数', undef],
);
# 出演者情報生成
#   定義(ロジック埋め込み)にしたがって、出演者情報配列を生成する
#   HTMLパラメータ名を操作するので、埋め込み定義とする
# 戻り値: 出演者情報配列参照
sub pg_CrtCastReg {
    my (
        $sprm,      # セッションオブジェクト(含企画パラメータ)
     ) = @_;
    my $pAcasts = [];

    # 申込者出演情報
    if ( $sprm->param('youdo') eq 'YD-0' ) {
        my $pHcast = {};
        $pHcast->{'name'}       = $sprm->param('p1_name');
        $pHcast->{'entrantregno'} = $sprm->param('reg_num');
        $pHcast->{'pgname'}     = $sprm->param('py_name');
        $pHcast->{'pgnamef'}    = $sprm->param('py_name_f');
        $pHcast->{'pgtitle'}    = $sprm->param('py_title');
        $pHcast->{'needreq'}    = '申込者';                 # 固定値
        $pHcast->{'needguest'}  = $ppn_grq_cnv{'PP-B'};     # 固定値
        push ( @$pAcasts, $pHcast );
    }
    # 出演者情報:(Loop)
    my $ppmax = $sprm->param('pp_cnt') + 1;
    for (my $ppcnt = 1; $ppcnt <= $ppmax; $ppcnt++) {
        my $prefix = 'pp' . $ppcnt;
        my $pgnamepn = $prefix . '_name';
        if (    defined($sprm->param($pgnamepn) )
             && ( $sprm->param($pgnamepn) ne '' ) ) {
            my $pHcast = {};
            my $pgnamefpn = $prefix . '_name_f';
            my $pgtitlepn = $prefix . '_title';
            my $needconpn = $prefix . '_con';
            my $needgrqpn = $prefix . '_grq';
            $pHcast->{'pgname'}   = $sprm->param($pgnamepn);
            $pHcast->{'pgnamef'}  = $sprm->param($pgnamefpn);
            $pHcast->{'pgtitle'}  = $sprm->param($pgtitlepn);
            $pHcast->{'needreq'}  = $ppn_con_cnv{$sprm->param($needconpn)};
            $pHcast->{'needguest'}= $ppn_grq_cnv{$sprm->param($needgrqpn)};
            push ( @$pAcasts, $pHcast );
        }
    }
    return($pAcasts);
}

##############################################################################
# デバッグテスト用共通関数
##############################################################################
# 共通関数 テスト用 HTMLにメール内容を埋め込む
sub pg_HtmlMailChk_set {
    my (
        $page,      # HTML::Templateオブジェクト
        $mbody,     # 埋め込むメール内容 1
        $mbody2,    # 埋め込むメール内容 2
    ) = @_;
        
    $page->param(MAILPRES => '<pre>')
        if ( $page->query(name => 'MAILPRES') );
    $page->param(MAILPREE => '</pre>')
        if ( $page->query(name => 'MAILPREE') );
    $page->param(MAILHR => '<hr/>')
        if ( $page->query(name => 'MAILHR') );
    $page->param(MAILBODY => $mbody)
        if ( $page->query(name => 'MAILBODY') );
    $page->param(MAILBODY2 => $mbody2)
        if ( $page->query(name => 'MAILBODY2') );
}

# 共通関数 テスト用 HTMLにJSONの値を埋め込む
sub pg_HtmlJson_set {
    my (
        $page,      # HTML::Templateオブジェクト
        $jsonbody,  # 埋め込むJSON値(テキスト化したもの)
    ) = @_;
        
    $page->param(JSONPRES => '<pre>')
        if ( $page->query(name => 'JSONPRES') );
    $page->param(JSONPREE => '</pre>')
        if ( $page->query(name => 'JSONPREE') );
    $page->param(JSONHR => '<hr/>')
        if ( $page->query(name => 'JSONHR') );
    $page->param(JSONBODY => $jsonbody)
        if ( $page->query(name => 'JSONBODY') );
}

# デバッグ出力
sub _DEBUG_ {
    return unless $CONDEF_CONST{'DEBUGLOG'};
    printf STDERR "[%s]", scalar(localtime);
    printf STDERR @_;
}

1;
#--EOF--
