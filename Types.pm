package Types;

use Moose::Util::TypeConstraints;
use Data::Validate::URI qw(is_http_uri);

subtype 'Lemma'
	=> as 'Str';
	
coerce 'Lemma'
	=> from 'Str'
	=> via {
		s/^([^\-\.,_;\/\\\^\?:\(\)!]*).*$/$1/;
		s/ +$//;
		lc;
	};

subtype 'URL'
	=> as 'Str'
	=> where { is_http_uri($_) }
    => message { 'Not a valid URL' };


1;