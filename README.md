prog_regist
==============
企画申込ページ

index.html
は汎用化していません。(cgiにすれば可能ですが、本質的ではないので)

大会ごとに必ず変更がある部分(大会名称とかメアドとか)は、すべて
    pgreglib.pm
の中で定義し、吸収しています。
(企画を登録するconkanのWebIF-URLやそのパラメータも)

入力項目など変更がありそうな部分は、
    XXXX.tmpl
に記述していますが、その中では
    pgreglib.pm
で定義した値を使っていますので、ほぼ変更はいらないはずです。
※入力項目を修正する場合は、conkanの設定変更と同期をとる必要があります

画像ファイル
    images/favicon.ico  images/header_logo.png
は、大会ごとに変更が必要です。

それ以外の
    *html *txt *cgi
は、変更なく次からも使えます。

下記のモジュールに依存します。
  [Perl5.14 CORE]
    CGI
    CGI::Carp
    Encode
    File::Basename
    Net::SMTP
    Sys::Hostname
  [さくら標準]
    CGI::Session
    HTML::Template
    HTTP::Request::Common
    LWP::UserAgent
    MIME::Base64
    Try::Tiny
  [独自インストール]
    Data::Dumper
    HTML::FillInForm
    JSON
    LWP::Protocol::https
