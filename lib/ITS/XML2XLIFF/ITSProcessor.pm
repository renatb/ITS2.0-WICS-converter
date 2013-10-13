package ITS::XML2XLIFF::ITSProcessor;
use strict;
use warnings;
use ITS qw(its_ns);
use Exporter::Easy (OK => [qw(its_requires_inline)]);

=head2 C<its_requires_inline>
Return true if converting the ITS info on the given element
requires that it be rendered inline (as mrk) instead of structural
(as its own source). Currently the only information tested for is terminology
information.

The arguments are the element being tested and the hash reference containing the global
information pertaining to it.
=cut
sub its_requires_inline {
    my ($el, $global) = @_;

    # any terminology information requires inlining
    if($el->att('term', its_ns())){
        return 1;
    }
    return 0 unless $global;
    if(exists $global->{term}){
        return 1;
    }
    return 0;
}

1;
