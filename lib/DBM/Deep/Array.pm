package DBM::Deep::Array;

use strict;

use base 'DBM::Deep';

sub _get_self {
    eval { tied( @{$_[0]} ) } || $_[0]
}

sub TIEARRAY {
##
# Tied array constructor method, called by Perl's tie() function.
##
    my $class = shift;
    my $args;
    if (scalar(@_) > 1) { $args = {@_}; }
    #XXX This use of ref() is bad and is a bug
	elsif (ref($_[0])) { $args = $_[0]; }
	else { $args = { file => shift }; }
	
	$args->{type} = $class->TYPE_ARRAY;
	
	return $class->_init($args);
}

##
# The following methods are for arrays only
##

sub FETCHSIZE {
	##
	# Return the length of the array
	##
    my $self = $_[0]->_get_self;
	
	my $SAVE_FILTER = $self->root->{filter_fetch_value};
	$self->root->{filter_fetch_value} = undef;
	
	my $packed_size = $self->FETCH('length');
	
	$self->root->{filter_fetch_value} = $SAVE_FILTER;
	
	if ($packed_size) { return int(unpack($DBM::Deep::LONG_PACK, $packed_size)); }
	else { return 0; } 
}

sub STORESIZE {
	##
	# Set the length of the array
	##
    my $self = $_[0]->_get_self;
	my $new_length = $_[1];
	
	my $SAVE_FILTER = $self->root->{filter_store_value};
	$self->root->{filter_store_value} = undef;
	
	my $result = $self->STORE('length', pack($DBM::Deep::LONG_PACK, $new_length));
	
	$self->root->{filter_store_value} = $SAVE_FILTER;
	
	return $result;
}

sub POP {
	##
	# Remove and return the last element on the array
	##
    my $self = $_[0]->_get_self;
	my $length = $self->FETCHSIZE();
	
	if ($length) {
		my $content = $self->FETCH( $length - 1 );
		$self->DELETE( $length - 1 );
		return $content;
	}
	else {
		return;
	}
}

sub PUSH {
	##
	# Add new element(s) to the end of the array
	##
    my $self = shift->_get_self;
	my $length = $self->FETCHSIZE();
	
	while (my $content = shift @_) {
		$self->STORE( $length, $content );
		$length++;
	}
}

sub SHIFT {
	##
	# Remove and return first element on the array.
	# Shift over remaining elements to take up space.
	##
    my $self = $_[0]->_get_self;
	my $length = $self->FETCHSIZE();
	
	if ($length) {
		my $content = $self->FETCH( 0 );
		
		##
		# Shift elements over and remove last one.
		##
		for (my $i = 0; $i < $length - 1; $i++) {
			$self->STORE( $i, $self->FETCH($i + 1) );
		}
		$self->DELETE( $length - 1 );
		
		return $content;
	}
	else {
		return;
	}
}

sub UNSHIFT {
	##
	# Insert new element(s) at beginning of array.
	# Shift over other elements to make space.
	##
    my $self = shift->_get_self;
	my @new_elements = @_;
	my $length = $self->FETCHSIZE();
	my $new_size = scalar @new_elements;
	
	if ($length) {
		for (my $i = $length - 1; $i >= 0; $i--) {
			$self->STORE( $i + $new_size, $self->FETCH($i) );
		}
	}
	
	for (my $i = 0; $i < $new_size; $i++) {
		$self->STORE( $i, $new_elements[$i] );
	}
}

sub SPLICE {
	##
	# Splices section of array with optional new section.
	# Returns deleted section, or last element deleted in scalar context.
	##
    my $self = shift->_get_self;
	my $length = $self->FETCHSIZE();
	
	##
	# Calculate offset and length of splice
	##
	my $offset = shift || 0;
	if ($offset < 0) { $offset += $length; }
	
	my $splice_length;
	if (scalar @_) { $splice_length = shift; }
	else { $splice_length = $length - $offset; }
	if ($splice_length < 0) { $splice_length += ($length - $offset); }
	
	##
	# Setup array with new elements, and copy out old elements for return
	##
	my @new_elements = @_;
	my $new_size = scalar @new_elements;
	
	my @old_elements = ();
	for (my $i = $offset; $i < $offset + $splice_length; $i++) {
		push @old_elements, $self->FETCH( $i );
	}
	
	##
	# Adjust array length, and shift elements to accomodate new section.
	##
    if ( $new_size != $splice_length ) {
        if ($new_size > $splice_length) {
            for (my $i = $length - 1; $i >= $offset + $splice_length; $i--) {
                $self->STORE( $i + ($new_size - $splice_length), $self->FETCH($i) );
            }
        }
        else {
            for (my $i = $offset + $splice_length; $i < $length; $i++) {
                $self->STORE( $i + ($new_size - $splice_length), $self->FETCH($i) );
            }
            for (my $i = 0; $i < $splice_length - $new_size; $i++) {
                $self->DELETE( $length - 1 );
                $length--;
            }
        }
	}
	
	##
	# Insert new elements into array
	##
	for (my $i = $offset; $i < $offset + $new_size; $i++) {
		$self->STORE( $i, shift @new_elements );
	}
	
	##
	# Return deleted section, or last element in scalar context.
	##
	return wantarray ? @old_elements : $old_elements[-1];
}

#XXX We don't need to define it.
#XXX It will be useful, though, when we split out HASH and ARRAY
#sub EXTEND {
	##
	# Perl will call EXTEND() when the array is likely to grow.
	# We don't care, but include it for compatibility.
	##
#}

##
# Public method aliases
##
*length = *FETCHSIZE;
*pop = *POP;
*push = *PUSH;
*shift = *SHIFT;
*unshift = *UNSHIFT;
*splice = *SPLICE;

1;
__END__