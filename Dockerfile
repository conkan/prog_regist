FROM httpd:2.4

MAINTAINER Studio-REM <rem@s-rem.jp>

#-------------------------------------------------------------------------
# 基本設定
#-------------------------------------------------------------------------
RUN apt-get -qq update
RUN apt-get -qq -y install apt-utils
RUN apt-get -qq -y install vim sudo unzip wget less build-essential libssl-dev cpanminus

#----------------------------------------------------------
# Perlライブラリインストール
#----------------------------------------------------------
RUN cpanm -in CGI CGI::Carp Encode File::Basename Net::SMTP Net::SMTPS Sys::Hostname CGI::Session HTML::Template HTTP::Request::Common LWP::UserAgent MIME::Base64 Try::Tiny Data::Dumper HTML::FillInForm JSON LWP::Protocol::https
RUN rm -rf .cpanm/*

#----------------------------------------------------------
# shell環境等設定
#----------------------------------------------------------
ENV HOSTNAME apache4pgreg
ADD doccnf/bashrc /root/.bashrc
ADD doccnf/vimrc /root/.vimrc
RUN rm -f /etc/localtime; ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
ENV TERM xterm
ENV LANG ja_JP.UTF8
ENV LANGAGE ja_JP.UTF8
ENV LC_ALL C
WORKDIR /root

#----------------------------------------------------------
# httpd設定
#----------------------------------------------------------
COPY ./pgreg/httpd.conf /usr/local/apache2/conf/httpd.conf

#----------------------------------------------------------
# program_entry実体格納(開発時はマウント)
# 大会独自設定ファイルはイメージから削除しておく
#----------------------------------------------------------
COPY ./pgreg/program_entry /usr/local/apache2/htdocs/program_entry
RUN rm -f /usr/local/apache2/htdocs/program_entry/pgregdef.pm

#----------------------------------------------------------
# 起動
#----------------------------------------------------------
EXPOSE 80
CMD [ "httpd-foreground"]
