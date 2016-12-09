# conkan連動 企画申込ページ

R1.0.0 CGIファイル提供のみ

## 概要

**index.html** は汎用化していません。(cgiにすれば可能ですが、本質的ではないので)

大会ごとに必ず変更がある部分(大会名称とかメアドとか)は、すべて **pgreglib.pm** の中で定義し、吸収しています。  
(企画を登録するconkanのWebIF-URLやそのパラメータも)

入力項目など変更がありそうな部分は、**XXXX.tmpl** に記述していますが、  
その中では **pgreglib.pm** で定義した値を使っていますので、ほぼ変更はいらないはずです。  
※入力項目を修正する場合は、conkanの設定変更と同期をとる必要があります

画像ファイル  
> **images/favicon.ico**  
> **images/header_logo.png**

は、大会ごとに変更が必要です。

それ以外の  
> **\*.html**  
> **\*.txt**  
> **\*.cgi**

は、変更なく次からも使えます。

## Perl依存モジュール

下記のモジュールに依存します。
- [Perl5.14 CORE]
    - CGI
    - CGI::Carp
    - Encode
    - File::Basename
    - Net::SMTP
    - Sys::Hostname
- [さくら標準]
    - CGI::Session
    - HTML::Template
    - HTTP::Request::Common
    - LWP::UserAgent
    - MIME::Base64
    - Try::Tiny
- [独自インストール]
    - Data::Dumper
    - HTML::FillInForm
    - JSON
    - LWP::Protocol::https

## インストール

### ファイル準備

**index.html** をシンボリックリンクで生成して下さい
> ln -s index_stable.html index.html  
>> これは、メンテナンス時に表示を切り替えるための仕組みです。

**pgreglib.pm** をcopyして生成して下さい
> cp pgreglib.pm_default pgreglib.pm  
>> これは、環境依存部分(セキュア情報を含む)を、GitHubに置かないための仕組みです。

### パラメータ設定

**pgreglib.pm** の、以下の部分を環境に合わせて設定して下さい。  
>    'CONNAME'    => '', # 大会愛称      ex. CCCC  
>    'CONPERIOD'  => '', # 有効期間      ex. 2015-2016  
>    'FULLNAME'   => '', # 大会正式名称  ex. 第NN回日本SF大会 CCCC  
>    'ENTADDR'    => '', # メールヘッダ差出人アドレス  
>    'ENVFROM'    => '', # ENVELOPE FROM アドレス  
>    'PGSTAFF'    => '', # 企画管理者アドレス (ML)  
>    'MIMENAME'   => '', # '第XX回日本SF大会 XXXX実行委員会' をMIME化した値  
>    'MIMEPGSG'   => '', # 'XXXX企画受付' をMIME化した値  
>    'CONKANURL'  => '', # conkanトップURL  
>    'CONKANPASS' => '', # conkan WebIF利用者(admin)パスワード  
>    # 以下デバッグ用  
>    'SPREGNUM1' => '',  # 直接申込jump用参加番号  
>    'SPREGNUM2' => '',  # 直接申込jump&FinalMail確認用参加番号  
>    'SPREGNUM3' => '',  # FirstMail確認用参加番号  
>    'SPPRIFIX'  => '',  # 特殊動作用プリフィックス
>    'DEVENV'    => hostname =~ /s-rem.jp/ ? 1 : undef,  
>> *MIMENAME および MIMEPGSG は、nkfなどでMIME化した値を設定*

### 評価用特殊参加番号

最初のページの *参加番号* に  
SPREGNUM1, SPREGNUM2, SPREGNUM3 に設定した値を入力すると、  
下記のような特殊な動作をします。(本番系でも同様)

- SPREGNUM1
> 申し込みフォームURL通知メールを送らず、申し込み画面にジャンプする

- SPREGNUM2
> 申し込みフォームURL通知メールを送らず、申し込み画面にジャンプする  
> 申し込み完了後、送信する通知メール(申込者宛、企画管理者宛)を送らず、画面に表示する

- SPREGNUM3
> 申し込みフォームURL通知メールの内容を、画面に表示する

さらに、*参加番号*に
> '<参加番号> <特殊動作指定プリフィックス> [ *オプション* ... ]'

の形でオプションを指定することで、細かな動作制御もできます。(本番系も同様)

オプションには以下のものが指定できます。

- NOURLMAIL
> 申し込みURL通知メールを送らず、直接企画申込画面に遷移

- NOMAIL2USER
> 申込者、企画管理者に申込受付メールを送らない

- NOMAIL2ML
> 企画管理MLに申込受付メールを送らない

- NOALLMAIL
> 全てのメールを送信しない

- SKIPVALID
> パラメータのバリデーションをせず、直接内容確認画面に遷移

- SKIPREGIST
> 実際の登録はしない

- SHOWURLMAIL
> 申し込みURL通知メール内容を画面に表示

- SHOWREGMAIL
> 申し込み完了後、送信する通知メール(申込者宛、企画管理者宛)を画面に表示する

- SHOWREGJSON
> conkan登録用JSON値を画面に表示する

このオプション指定文字列も、pgreglib.pmを修正することで変更することができますが、指定した特殊動作用プリフィックスを入力しないかぎり動作しませんので、あえて変える必要はないでしょう。

EOF
