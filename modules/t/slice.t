use strict;
use warnings;

use lib 't';

BEGIN { $| = 1;
	use Test;
	plan tests => 40;
}

use TestUtils qw( debug );

use MultiTestDB;
use Bio::EnsEMBL::Slice;

our $verbose= 0;

#
# TEST - Slice Compiles
#
ok(1);


my $CHR           = '20';
my $START         = 30_270_000;
my $END           = 31_200_000;
my $STRAND        = 1;

my $multi_db = MultiTestDB->new;
my $db = $multi_db->get_DBAdaptor('core');

#
# TEST - Slice creation from adaptor
#
my $slice_adaptor = $db->get_SliceAdaptor;
my $csa = $db->get_CoordSystemAdaptor();

my $slice = $slice_adaptor->fetch_by_region('chromosome', $CHR, $START, $END);
ok($slice->seq_region_name eq $CHR);
ok($slice->start == $START);
ok($slice->end == $END);
ok($slice->adaptor == $slice_adaptor);


#
#TEST - Slice::new
#
my $coord_system = $csa->fetch_by_name('toplevel');

$slice = new Bio::EnsEMBL::Slice
  (-seq_region_name  => $CHR,
   -start            => $START,
   -end              => $END,
   -strand           => $STRAND,
   -coord_system     => $coord_system);


ok($slice->seq_region_name eq $CHR);
ok($slice->start == $START);
ok($slice->end == $END);
ok($slice->strand == $STRAND);

#
#Test - Slice::adaptor
#
$slice->adaptor($slice_adaptor);
ok($slice->adaptor == $slice_adaptor);


#
#1 Test Slice::name
#
#verify that chr_name start and end are contained in the name
my $name = $slice->name;
ok($name eq "chromosome:NCBI33:$CHR:$START:$END:$STRAND");

#
# Test Slice::length
#
ok($slice->length == ($END-$START + 1));


#
# Test get_attributes
#

my $clone = $slice_adaptor->fetch_by_region('clone','AL121583.25');

my @types = $clone->get_attribute_types();

ok(@types == 1 && $types[0] eq 'htg_phase');

my @attrib = $clone->get_attribute('htg_phase');

ok(@attrib == 1 && $attrib[0] == 4);

#
# Test expand
#
my $len = $clone->length();

$clone = $clone->expand(100,100);
ok(($clone->start == -99) && ($clone->end() == $len+100));

$clone = $clone->expand(-100,-100);
ok(($clone->start == 1) && ($clone->end() == $len));

$clone = $clone->expand(0,1000);
ok(($clone->start == 1) && ($clone->end() == $len + 1000));

$clone = $clone->expand(-1000, 0);
ok(($clone->start == 1001) && ($clone->end() == $len + 1000));


#
# Test Slice::invert
#
my $inverted_slice = $slice->invert;
ok($slice != $inverted_slice); #slice is not same object as inverted slice
#inverted slice on opposite strand
ok($slice->strand == ($inverted_slice->strand * -1)); 
#slice still on same strand
ok($slice->strand == $STRAND);


#
# Test Slice::seq
#
my $seq = uc $slice->seq;
my $invert_seq = uc $slice->invert->seq;

ok(length($seq) == $slice->length); #sequence is correct length

$seq = reverse $seq;  #reverse complement seq
$seq =~ tr/ACTG/TGAC/; 

ok($seq eq $invert_seq); #revcom same as seq on inverted slice

#
# Test Slice::subseq
#
my $SPAN = 10;
my $sub_seq = uc $slice->subseq(-$SPAN,$SPAN);
my $invert_sub_seq = uc $slice->invert->subseq( $slice->length - $SPAN + 1, 
						$slice->length + $SPAN + 1);

ok(length $sub_seq == (2*$SPAN) + 1 ); 
$sub_seq = reverse $sub_seq;
$sub_seq =~ tr/ACTG/TGAC/;

ok($sub_seq eq $invert_sub_seq);

#
# Test Slice::get_all_PredictionTranscripts
#
my $pts = $slice->get_all_PredictionTranscripts;
ok(@$pts == 24);

#
# Test Slice::get_seq_region_id
#
ok($slice->get_seq_region_id());

#
# Test Slice::get_all_DnaAlignFeatures
#
my $count = 0;
my $dafs = $slice->get_all_DnaAlignFeatures;
ok(@$dafs == 27081);
$count += scalar @$dafs;

#
# Test Slice::get_all_ProteinAlignFeatures
#
my $pafs = $slice->get_all_ProteinAlignFeatures;
ok(@$pafs == 7205);
$count += scalar @$pafs;

#
# Test Slice::get_all_SimilarityFeatures
#
ok($count == scalar @{$slice->get_all_SimilarityFeatures});

#
#  Test Slice::get_all_SimpleFeatures
#
ok(scalar @{$slice->get_all_SimpleFeatures});

#
#  Test Slice::get_all_RepeatFeatures
#
ok(scalar @{$slice->get_all_RepeatFeatures});

#
#  Test Slice::get_all_Genes
#
ok(scalar @{$slice->get_all_Genes});

#
#  Test Slice::get_all_Genes_by_type
#
ok(scalar @{$slice->get_all_Genes_by_type('ensembl')});



#
# Test Slice::get_all_KaryotypeBands
#
ok(scalar @{$slice->get_all_KaryotypeBands});


#
# Test Slice::get_RepeatMaskedSeq
#
$seq = $slice->seq;
ok(length($slice->get_repeatmasked_seq->seq) == length($seq));

my $softmasked_seq = $slice->get_repeatmasked_seq(['RepeatMask'], 1)->seq;

ok($softmasked_seq ne $seq);
ok(uc($softmasked_seq) eq $seq);

$softmasked_seq = $seq = undef;

#
# Test Slice::get_all_MiscFeatures
#
ok(scalar @{$slice->get_all_MiscFeatures()});

#
# Test Slice::project
#
ok(scalar @{$slice->project('seqlevel')});


#my $super_slices = $slice->get_all_supercontig_Slices();


##
## get_all_supercontig_Slices()
##
#debug( "Supercontig starts at ".$super_slices->[0]->chr_start() );

#ok( $super_slices->[0]->chr_start() == 29591966 );

#debug( "Supercontig name ".$super_slices->[0]->name() );

#ok( $super_slices->[0]->name() eq "NT_028392" );

#
# get_base_count
#
my $hash = $slice->get_base_count;
my $a = $hash->{'a'};
my $c = $hash->{'c'};
my $t = $hash->{'t'};
my $g = $hash->{'g'};
my $n = $hash->{'n'};
my $gc_content = $hash->{'%gc'};

debug( "Base count: a=$a c=$c t=$t g=$g n=$n \%gc=$gc_content");
ok($a == 234371 
   && $c == 224761 
   && $t == 243734 
   && $g == 227135 
   && $n == 0 
   && $gc_content == 48.59 
   && $a+$c+$t+$g+$n == $slice->length);


