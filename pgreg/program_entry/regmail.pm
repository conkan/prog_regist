#!/usr/bin/perl
package regmail;
use strict;
use warnings;
use Encode qw/ encode decode /;
use Net::SMTP;
use Net::SMTP::TLS;

use pgregdef;

require Exporter;
use base qw/Exporter/;

our @EXPORT = qw(
    doMailSend
);

our %EXPORT_TAGS = (
    default      => [ @EXPORT ],
);

# 共通関数 mail送信
sub doMailSend {
    my (
        $envfrom,   # EnvelopeFrom
        $pAenvto,   # EnvelopeTo配列参照
        $body,      # メール本文
    ) = @_;

    my $smtp;
    if ( $CONDEF_CONST{'SMTP'}->{'TLS'} ) {
        $smtp = Net::SMTP::TLS->new(
            $CONDEF_CONST{'SMTP'}->{'SERVER'},
            Port        => $CONDEF_CONST{'SMTP'}->{'PORT'},
            User        => $CONDEF_CONST{'SMTP'}->{'AUTH_USER'},
            Password    => $CONDEF_CONST{'SMTP'}->{'AUTH_PASS'}
        );
    } else {
        $smtp = Net::SMTP->new(
            $CONDEF_CONST{'SMTP'}->{'SERVER'},
            Port        => $CONDEF_CONST{'SMTP'}->{'PORT'}
        );
        if ( $CONDEF_CONST{'SMTP'}->{'AUTH'} ) { 
			$smtp->auth( $CONDEF_CONST{'SMTP'}->{'AUTH_USER'},
                         $CONDEF_CONST{'SMTP'}->{'AUTH_PASS'} );
		}
	}

    $smtp->mail($envfrom);
    foreach my $envto ( @$pAenvto ) {
        $smtp->to($envto);
    }
    $smtp->data();
    $smtp->datasend( encode('7bit-jis', decode('utf8', $body)) );
    $smtp->dataend();
    $smtp->quit;
}
