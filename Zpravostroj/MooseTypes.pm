package Zpravostroj::MooseTypes;
#nejake veci na Moose koercovani a subtypovani


use Moose::Util::TypeConstraints;
use Data::Validate::URI qw(is_http_uri);

subtype 'Lemma'
	=> as 'Str';

#odstrani z Lemmatu bordel
coerce 'Lemma'
	=> from 'Str'
	=> via {
		s/^([^\-\.,_;\/\\\^\?:\(\)!"]*).*$/$1/;
		s/^([\-\.,_;\/\\\^\?:\(\)!"]*)$//;
		s/ +$//;
		lc;
	};


#kontroluje, jestli je URL validni URL
subtype 'URL'
	=> as 'Str'
	=> where { is_http_uri($_) }
    => message { 'Not a valid URL' };


1;