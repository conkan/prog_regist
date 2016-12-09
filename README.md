# conkan連動 企画申込ページ

R1.0.0 CGIファイル提供のみ

## 概要

大会ごとに必ず変更がある部分(大会名称とかメアドとか)は、すべて **pgregdef.pm** の中で定義し、吸収しています。  
(企画を登録するconkanのWebIF-URLやそのパラメータも)

入力項目など変更がありそうな部分は、**XXXX.tmpl** に記述していますが、  
radioboxの選択肢などには **pgregdef.pm** で定義した値を使っていますので、
ほぼ変更はいらないはずです。  
※入力項目を修正(増減)する場合は、conkanの設定変更と同期をとる必要があります

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

Perlのモジュールは、Dockerfile の Perlライブラリインストール部分を参照してください。

## デプロイ

企画申し込みページを起動する方法は2つあります。

いずれの場合も、まずサーバ上の任意の場所(以下<BASE>)に
git リポジトリをcloneしてください。

+----
|prompt> cd <BASE>
|prompt> git clone https://github.com/conkan/prog_regist.git
+----

### Dockerコンテナとして起動

Docker Hubに conkan/apache4pgreg コンテナが登録されるまでは、
独自にコンテナイメージを作成する必要があります。
コンテナイメージの作成には、build.shを起動します。
+----
|prompt> cd <BASE>/prog_regist
|prompt> ./build.sh
+----

コンテナの起動には、run.shを起動します。
+----
|prompt> cd <BASE>/prog_regist
|prompt> ./run.sh product
+----
引数にproductを指定すると、prog_regist本体(CGI)としてコンテナ内部のもの(build.sh時のもの)を使用します。
引数を指定しない場合、prog_regist本体(CGI)としてgit cloneしたもの(<BASE>/prog_regist/pgreg/program_entry)を使用します。

この方法で起動した場合、
- prog_regist用httpdは、下記の状態になります
  -- 待受プロトコル        ; http
  -- 待受port              : 9001
  -- prog_registトップパス : /program_entry
  -- ログ出力ディレクトリ  : ホスト側の /var/log/http4pgreg

  ホスト側のリバースプロキシ(nginxなど)で、SSL解釈とプロキシパスを設定してください。
  [nginxの場合の設定例 nginx.conf]
   +----
   |server {
   |    listen       443 ssl default_server;
   |    ssl          on;
        : (server_nameやsslの設定は省略)
   |    # For program_regist
   |    location /program_entry {
   |            proxy_pass http://localhost:9001/program_entry;
   |    }
        : (他location やeror_pageの設定は省略)
   |}
   +----

コンテナ起動後、後述の「大会独自ファイル設定」を実施してください。

### 既存httpdに直接CGIを配置

サーバで動作しているhttpd(apacheなど)のCGIとして動作させる場合には、
prog_regist本体(<BASE>/prog_regist/pgreg/program_entry)を、
ドキュメントルート下の適切な部分にcopy(あるいはシンボリックリンク)して、
下記の設定をしてください。
- CGI起動可能とする
- cgi-scriptのHandlerとして cgi を設定する
- DirectoryIndex として index.cgiを使用

なお、当然ながらSSL解釈の設定なども必要です。

  [apache2の場合の設定例 httpd.conf]
  prog_regist本体のパスを<PGREG>とする
   +----
   |<Directory "<PGREG>">
   |    AllowOverride All
   |    Options MultiViews SymLinksIfOwnerMatch ExecCGI
   |    <Limit GET POST OPTIONS>
   |        Order allow,deny
   |        Allow from all
   |    </Limit>
   |    <LimitExcept GET POST OPTIONS>
   |        Order deny,allow
   |        Deny from all
   |    </LimitExcept>
   |    AddHandler cgi-script cgi pl
   |    DirectoryIndex index.html index.cgi
   |</Directory>
   +----

加えて、後述の「大会独自ファイル設定」を実施後、httpdを再起動してください。

### 大会独自ファイル設定

画像ファイル  
> **images/favicon.ico**  
> **images/header_logo.png**
を対応大会の物に上書きしてください。

**pgregdef.pm** をcopyして生成して下さい
> cp pgregdef.pm_default pgregdef.pm  
>> これは、環境依存部分(セキュア情報を含む)を、GitHubに置かないための仕組みです。

**pgregdef.pm** の内容を環境に合わせて設定して下さい。  
個々の項目に関しては、**pgregdef.pm** のコメントを参照してください。

EOF
