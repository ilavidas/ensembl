use strict;
use warnings;

package Insertion;

use InterimExon;
use Length;
use StatMsg;
use Bio::EnsEMBL::Utils::Exception qw(throw info);


sub process_insert {
  my $cdna_ins_pos_ref = shift;   #basepair to left of insert
  my $insert_len       = shift;
  my $exon             = shift;
  my $transcript       = shift;

  info("insert ($insert_len)");

  my $code = StatMsg::EXON | StatMsg::INSERT |
             Length::length2code($insert_len);

  # sanity check, insert should be completely in exon boundaries
  if($$cdna_ins_pos_ref <  $exon->cdna_start() ||
     $$cdna_ins_pos_ref >= $exon->cdna_end()) {

    # because some small (<3bp) matches can be completely eaten away by the
    # introduction of frameshift introns it is possible to get an insert
    # immediately before a newly created (i.e.) split intron

    if($$cdna_ins_pos_ref < $exon->cdna_start  &&
       $$cdna_ins_pos_ref + 3 >= $exon->cdna_start  ) {
      ### TBD not sure what should be done with this situation

      $exon->add_StatMsg(StatMsg->new($code | StatMsg::CONFUSED));
      $exon->fail(1);
      return;
    }

    throw("Unexpected: insertion is outside of exon boundary\n" .
          "     ins_left       = $$cdna_ins_pos_ref\n" .
          "     ins_right      = " . ($$cdna_ins_pos_ref+1) . "\n" .
          "     cdna_exon_start = ". $exon->cdna_start()."\n" .
          "     cdna_exon_end   = ". $exon->cdna_end()."\n");
  }


  #
  # case 1: insert in CDS
  #
  if($$cdna_ins_pos_ref >= $transcript->cdna_coding_start() &&
     $$cdna_ins_pos_ref <  $transcript->cdna_coding_end()) {

    info("insertion in cds ($insert_len)");
    # print "BEFORE CDS INSERT:\n";
    # print_exon($exon);

    $code |= StatMsg::CDS;

    # adjust CDS end accordingly
    $transcript->move_cdna_coding_end($insert_len);

    my $frameshift = $insert_len % 3;


    if($frameshift) {
      $code |= StatMsg::FRAMESHIFT;

      # need to create frameshift intron to get reading frame back on track
      # exon needs to be split into two

      info("introducing frameshift intron to maintain reading frame");

      # first exon ends right before insert
      my $first_len  = $$cdna_ins_pos_ref - $exon->cdna_start() + 1;

      # copy the original exon and adjust coords of each to perform 'split'
      my $first_exon = InterimExon->new();
      %{$first_exon} = %{$exon};
      $exon->flush_StatMsgs();

      # frame shift intron eats into start of inserted region
      # second exon is going to start right after 'frameshift intron'
      # which in cdna coords is immediately after last exon
      $first_exon->cdna_end($first_exon->cdna_start + $first_len - 1);
      $exon->cdna_start($first_exon->cdna_end + 1);

      # decrease the length of the CDS by the length of new intron
      $transcript->move_cdna_coding_end(-$frameshift);

      # the insert length will be added to the cdna_position
      # but part of the insert was used to create the intron and is not cdna
      # anymore, so adjust the cdna_position to compensate
      $$cdna_ins_pos_ref -= $frameshift;

      ### TBD may have to check we have not run up to end of CDS here

      if($exon->strand() == 1) {
        # end the first exon at the beginning of the insert
        $first_exon->end($first_exon->start() + $first_len -1 );

        # start the next exon after the frameshift intron
        $exon->start($exon->start() + $first_len + $frameshift);
      } else {
        $first_exon->start($first_exon->end() - $first_len + 1);

        # start the next exon after the frameshift intron
        $exon->end($exon->end() - ($first_len + $frameshift));
      }
    }

    # print "AFTER CDS INSERT:\n";
    # print_exon($exon);

  }

  #
  # case 2: insert in 5 prime UTR (or between 5prime UTR and CDS)
  #
  elsif($$cdna_ins_pos_ref < $transcript->cdna_coding_start()) {
    info("insertion ($insert_len) in 5' utr");

    $code |= StatMsg::FIVE_PRIME | StatMsg::UTR;

    #shift the coding region down as result of insert
    $transcript->move_cdna_coding_start($insert_len);
    $transcript->move_cdna_coding_end($insert_len);
  }

  #
  # case 3: insert in 3 prime UTR (or between 3prime UTR and CDS)
  #
  elsif($$cdna_ins_pos_ref >= $transcript->cdna_coding_end()) {
    info("insert ($insert_len) in 3' utr");

    $code |= StatMsg::THREE_PRIME | StatMsg::UTR;

    #do not have to do anything
  }

  #
  # default: sanity check
  #
  else {
    throw("Unexpected insert case encountered");
  }


  $exon->add_StatMsg(StatMsg->new($code));

  return;
}

#sub print_exon {
  #my $exon = shift;

  #if(!$exon) {
   #throw("Exon undefined");
  #}
	
                                                                                
  #print "EXON:\n";
  #print "cdna_start = ". $exon->cdna_start() . "\n";
  #print "cdna_end   = ". $exon->cdna_end() . "\n";
  #print "start             = ". $exon->start() . "\n";
  #print "end               = ". $exon->end() . "\n";
  #print "strand            = ". $exon->strand() . "\n\n";
                                                                                
  #return;
#}


1;
