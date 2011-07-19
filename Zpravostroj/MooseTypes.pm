package Zpravostroj::MooseTypes;
#Různé pomocné Moose typy, které používám

use Zpravostroj::Globals;
use Moose::Util::TypeConstraints;
use Data::Validate::URI qw(is_http_uri);

#Lemma je normální string, ale díky "coercingu" je vyčištěn od pomocných značek,
#které tagger vyhodí, ale já je nechci
subtype 'Lemma'
	=> as 'Str';

coerce 'Lemma'
	=> from 'Str'
	=> via {
		cleanup_lemma($_);
	};


#kontroluje, jestli je URL validni URL
subtype 'URL'
	=> as 'Str'
	=> where { is_http_uri($_) }
    => message { 'Not a valid URL' };


1;