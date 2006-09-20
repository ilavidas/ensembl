# EnsEMBL module for DitagFeatures
#
# Copyright EMBL-EBI/Wellcome Trust Sanger Institute 2006
#
# You may distribute this module under the same terms as perl itself
#
# Cared for by EnsEMBL (ensembl-dev@ebi.ac.uk)


=head1 NAME

Bio::EnsEMBL::Map::DitagFeature

=head1 SYNOPSIS

 my $feature = Bio::EnsEMBL::Map::DitagFeature->new(
						    -slice         => $slice,
						    -start         => $qstart,
						    -end           => $qend,
						    -strand        => $qstrand,
						    -hit_start     => $tstart,
						    -hit_end       => $tend,
						    -hit_strand    => $tstrand,
						    -ditag_id      => $ditag_id,
						    -ditag_side    => $ditag_side,
						    -ditag_pair_id => $ditag_pair_id,
						    -cigar_line    => $cigar_line,
						    -analysis      => $analysis,
						   );

=head1 DESCRIPTION

Represents a mapped ditag object in the EnsEMBL database.
These are the original tags separated into start ("L") and end ("R") parts if applicaple,
successfully aligned to the genome. Two DitagFeatures usually relate to one parent Ditag.
Alternatively there are CAGE tags e.g. which only have a 5\'tag ("F").

=cut

package Bio::EnsEMBL::Map::DitagFeature;

use strict;
use vars qw(@ISA);

#use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument  qw( rearrange );

@ISA = qw(Bio::EnsEMBL::Feature);

=head2 new

  Arg [1]    : (optional) int dbID
  Arg [2]    : (optional) Bio::EnsEMBL::DitagFeatureAdaptor $adaptor
  Arg [3]    : int start
  Arg [4]    : int end
  Arg [5]    : int strand
  Arg [6]    : Bio::EnsEMBL::Slice $slice
  Arg [7]    : (optional) Bio::EnsEMBL::Analysis
  Arg [8]    : int hit_start
  Arg [9]    : int hit_end
  Arg [10]   : int hit_strand
  Arg [11]   : int ditag_id
  Arg [12]   : string ditag_side
  Arg [13]   : (optional) sring cigar_line
  Arg [14]   : (optional) int ditag_pair_id
  Arg [15]   : (optional) int tag_count, only used for imported mappings where
               identical positions where collapsed into into one feature.
               Default: 1

  Example    : $ditag = Bio::EnsEMBL::Map::DitagFeature->new
                            (-dbID => 123, -adaptor => $adaptor, ...);
  Description: Creates a new DitagFeature
  Returntype : Bio::EnsEMBL::Map::DitagFeature
  Caller     : general

=cut

sub new {
  my ($caller, @args) = @_;
  my ( $dbID, $adaptor, $start, $end, $strand, $slice, $analysis, $hit_start, $hit_end, 
       $hit_strand, $ditag_id, $ditag_side, $cigar_line, $ditag_pair_id, $tag_count ) = rearrange( 
												  [ 'dbid', 'adaptor' ,'start', 'end', 'strand', 'slice', 'analysis', 'hit_start', 
	'hit_end', 'hit_strand', 'ditag_id', 'ditag_side', 'cigar_line', 'ditag_pair_id' ,'tag_count'],
       @args );
  my $class = ref($caller) || $caller;

  if($analysis) {
    if(!ref($analysis) || !$analysis->isa('Bio::EnsEMBL::Analysis')) {
      throw('-ANALYSIS argument must be a Bio::EnsEMBL::Analysis not '.
            $analysis);
    }
  }
  if(defined($strand)) {
    if(!($strand =~ /^-?\d$/) or !($strand == 1) && !($strand == -1) && !($strand == 0)) {
      throw('-STRAND argument must be 1, -1, or 0');
    }
  }
  if(defined($hit_strand)) {
    if(!($hit_strand == 1) && !($hit_strand == -1) && !($hit_strand == 0)) {
      throw('-HIT_STRAND argument must be 1, -1, or 0 not '.$hit_strand);
    }
  }
  if(defined($start) && defined($end)) {
    if($end+1 < $start) {
      throw('Start must be less than or equal to end+1.');
    }
  }
  else{
    throw('Need start and end location.');
  }
  if(!(defined($hit_start) && defined($hit_end))) {
    throw('Need hit start and hit end location.');
  }
  if(!defined($tag_count) or (!$tag_count =~ /^[\d]+$/)){
    $tag_count = 1;
  }

  my $self = bless( {'dbID'          => $dbID,
                     'analysis'      => $analysis,
                     'adaptor'       => $adaptor,
                     'slice'         => $slice,
                     'start'         => $start,
                     'end'           => $end,
		     'strand'        => $strand,
		     'hit_start'     => $hit_start,
		     'hit_end'       => $hit_end,
		     'hit_strand'    => $hit_strand,
                     'ditag_id'      => $ditag_id,
		     'ditag_pair_id' => $ditag_pair_id,
                     'ditag_side'    => $ditag_side,
                     'cigar_line'    => $cigar_line,
		     'tag_count'     => $tag_count,
                    }, $class);

  return $self;
}


=head2 fetch_ditag

  Arg [1]    : none
  Description: Get the ditag object of this DitagFeature
  Returntype : Bio::EnsEMBL::Map::Ditag
  Exceptions : none
  Caller     : general

=cut

sub fetch_ditag {
  my $self = shift;

  my $ditag_adaptor = $self->adaptor->db->get_DitagAdaptor;
  my $ditag = $ditag_adaptor->fetch_by_dbID($self->ditag_id);

  return $ditag;
}


=head2 get_ditag_location

  Arg [1]    : none
  Description: Get the start and end location (and strand ) of the start-end pair
               this DitagFeature belongs to.
               If it is not a paired ditag, these will be identical
               to DitagFeature->start() & DitagFeature->end().
               Please note that the returned start/end are min/max locations.
  Returntype : int (start, end, strand)
  Exceptions : throws if the 2 features of a pair are found on different strands
               or if the second one cannot be found.
  Caller     : general

=cut

sub get_ditag_location {
  my $self = shift;

  my ($start, $end, $strand);
  if($self->ditag_side eq "F"){
    $start = $self->start;
    $end   = $self->end;
  }
  else{
    my ($ditag_a, $ditag_b, $more);
    eval{
     ($ditag_a, $ditag_b, $more) = @{$self->adaptor->fetch_all_by_ditagID($self->ditag_id, $self->ditag_pair_id)};
    };
    if($@ or !defined($ditag_a) or !defined($ditag_b)){
      throw("Cannot find 2nd tag of pair (".$self->dbID.", ".$self->ditag_id.", ".$self->ditag_pair_id.")");
    }
    else{
      if(defined $more){
	throw("More than two DitagFeatures were returned for ".$self->dbID.", ".$self->ditag_id.", ".$self->ditag_pair_id);
      }

      ($ditag_a->start < $ditag_b->start) ? ($start = $ditag_a->start) : ($start = $ditag_b->start);
      ($ditag_a->end   > $ditag_b->end)   ? ($end   = $ditag_a->end)   : ($end   = $ditag_b->end);
      if($ditag_a->strand != $ditag_b->strand){
	throw('the strand of the two ditagFeatures are different! '.$ditag_a->strand.'/'.$ditag_b->strand);
      }
    }
  }

  return($start, $end, $self->strand);
}


=head2 property functions

  Arg [1]    : (optional) value
  Description: Getter/Setter for the different properties
               of this DitagFeature
  Returntype : int or string
  Exceptions : none
  Caller     : general

=cut

sub ditag_id {
  my $self = shift;

  if(@_) {
    $self->{'ditag_id'} = shift;
  }

  return $self->{'ditag_id'};
}

sub slice {
  my $self = shift;

  if(@_) {
    $self->{'slice'} = shift;
  }

  return $self->{'slice'};
}

sub ditag_pair_id {
  my $self = shift;

  if(@_) {
    $self->{'ditag_pair_id'} = shift;
  }

  return $self->{'ditag_pair_id'};
}

sub ditag_side {
  my $self = shift;

  if(@_) {
    $self->{'ditag_side'} = shift;
  }

  return $self->{'ditag_side'};
}

sub hit_start {
  my $self = shift;

  if(@_) {
    $self->{'hit_start'} = shift;
  }

  return $self->{'hit_start'};
}

sub hit_end {
  my $self = shift;

  if(@_) {
    $self->{'hit_end'} = shift;
  }

  return $self->{'hit_end'};
}

sub hit_strand {
  my $self = shift;

  if(@_) {
    $self->{'hit_strand'} = shift;
  }

  return $self->{'hit_strand'};
}

sub cigar_line {
  my $self = shift;

  if(@_) {
    $self->{'cigar_line'} = shift;
  }

  return $self->{'cigar_line'};
}

sub start {
  my $self = shift;

  if(@_) {
    $self->{'start'} = shift;
  }

  return $self->{'start'};
}

sub end {
  my $self = shift;

  if(@_) {
    $self->{'end'} = shift;
  }

  return $self->{'end'};
}

sub strand {
  my $self = shift;

  if(@_) {
    $self->{'strand'} = shift;
  }

  return $self->{'strand'};
}

sub dbID {
  my $self = shift;

  if(@_) {
    $self->{'dbID'} = shift;
  }

  return $self->{'dbID'};
}

sub sequence {
  my $self = shift;

  $self->{'sequence'} = $self->adaptor->sequence($self->dbID());

  return $self->{'sequence'};
}


1;
