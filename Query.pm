package Mail::Query;

require 5.005_62;
use strict;
use warnings;
use base 'Mail::Audit';
use Parse::RecDescent;
our $VERSION = '0.01';

sub new {
  my $package = shift;
  
  my $self = $package->SUPER::new(@_);
  $self->{parser} = new Parse::RecDescent($self->grammar);
  return $self;
}

sub query {
  my ($self, $query) = @_;
  local $self->{parser}{local}{mq} = $self;  # Circular ref, but local.  No sweat.
  return $self->{parser}->where_clause($query);
}

sub compare {
  my ($self, $field, $op, $string) = @_;
  
#warn "compare($field, $op, $string)";
  # We handle =, <, and >
  return !$self->compare($field, '=', $string) if $op eq '!=';
  return !$self->compare($field, '<', $string) if $op eq '>=';
  return !$self->compare($field, '>', $string) if $op eq '<=';


  # This should be date-aware, at the least.  So far we punt.
  my $val = $self->get($field);
  #warn "comparing: '$val' $op '$string'";
  return $val eq $string if $op eq '=';
  return $val lt $string if $op eq '<';
  return $val gt $string if $op eq '>';
  
  die "Unknown operator '$op'";
}

sub between {
  my ($self, $field, $one, $two) = @_;
  
  # This should be date-aware, at the least.  So far we punt.
  ($one, $two) = ($two, $one) if $one gt $two;
  return 0 unless $one lt $field;
  return 0 unless $field lt $two;
  return 1;
}

sub like {
  my ($self, $field, $pattern) = @_;

  return eval "\$self->get(\$field) =~ $pattern->[0]"  # eval to maintain 5.004 compat
    if $pattern->[1] eq 'regex';
  
  # $pattern->[1] eq 'string'
  # A string like 'boo%hoo' maps to /^boo.*hoo$/
  my $string = quotemeta($pattern->[0]);
  $string =~ s/%/.*/;
  return $self->get($field) =~ /^$string$/;
}

sub exists {
  my ($self, $field) = @_;
#my $val = $self->get($field);
#warn "checking for field '$field': '$val' (", defined($val), ")";

  return defined $self->get($field);
}

# We implement a 'Recipient' field, which is any of To, Cc, or Bcc
sub get {
  my ($self, $field) = @_;
  return join '', @{$self->body} if lc($field) eq 'body';
  return $self->SUPER::get($field) unless lc($field) eq 'recipient';
  return join ', ', map {$self->SUPER::get($_)} qw(To Cc Bcc);
}

sub grammar {
  return <<'EOF';
    # Excised from http://www.contrib.andrew.cmu.edu/~shadow/sql/sql2bnf.aug92.txt
    
    where_clause: search_condition /^\Z/                     {$return = $item[1]}
                | <error>
    
    search_condition: bool_term or <commit> search_condition {$return = $item[1] || $item[3]}
                    | bool_term
    
    bool_term: bool_factor and <commit> bool_term            {$return = $item[1] && $item[3]}
             | bool_factor
    
    bool_factor: not(?) bool_primary                {$return = @{$item[1]} ? !$item[2] : $item[2]}
    # Don't support IS TRUE and IS NOT UNKNOWN and all that crap
    
    bool_primary: predicate
                | '(' search_condition ')' {$return = $item[2]}
    
    predicate: comparison_predicate
             | between_predicate
             | like_predicate
             | null_predicate
              # There's more here, but I'm skipping for now.
    
    # These only accept header field names as the LHS, and don't allow functions yet.
    comparison_predicate: header comp_op string        {$return = $thisparser->{local}{mq}->compare(@item[1,2,3])}
    
    between_predicate: header not(?) between string and string
                                                         {my $x = $thisparser->{local}{mq}->between(@item[1,4,6]);
							  $return = @{$item[2]} ? !$x : $x}
    
    like_predicate: header not(?) like rhs               {my $x = $thisparser->{local}{mq}->like(@item[1,4]);
							  $return = @{$item[2]} ? !$x : $x}
    
    null_predicate: header is not(?) null                {my $x = $thisparser->{local}{mq}->exists($item[1]);
						          $return = @{$item[3]} ? $x : !$x}

    rhs: string[1]
       | regex

    string: {my @x = extract_quotelike($text);
             if ($x[0] and ($x[3] =~ m/^q+$/ or $x[4] =~ m/^['"]$/) ) {
               substr($text,0,pos($text)) = '';
               $return = $arg[0] ? [$x[5],'string'] : $x[5];
             } else {
               $return = undef;
             }
            }
	     #$return = (m/^(?:q|qq)\W/ or m/^['"]/) ? ($arg[0] ? [$_,'string'] : $_) : undef} #']);} heh
    
    regex:  {local $_ = extract_quotelike($text);
	     $return = (m/^m/ or m/^\//) ? [$_,'regex'] : undef}

    comp_op: '=' | '!=' | '<=' | '>=' | '<' | '>'
    
    header: /[\w-]+/  # dashes are allowed, very common in headers.
    
    or:   /OR/i
    and:  /AND/i
    not:  /NOT/i
    is:   /IS/i
    like: /LIKE/i
    null: /NULL/i
    between: /BETWEEN/i

EOF
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Mail::Query - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Mail::Query;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Mail::Query, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
