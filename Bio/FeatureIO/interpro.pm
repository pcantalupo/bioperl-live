package Bio::FeatureIO::interpro;

use strict;
use base qw(Bio::FeatureIO);
use Bio::SeqFeature::Annotated;
use Bio::OntologyIO;

use Bio::Annotation::DBLink;
use Bio::Annotation::OntologyTerm;
use Bio::Annotation::SimpleValue;
use Bio::Annotation::Target;

use URI::Escape;
use XML::DOM;
use XML::DOM::XPath;

sub _initialize {
  my($self,%arg) = @_;

  $self->SUPER::_initialize(%arg);
  $self->xml_parser(XML::DOM::Parser->new());
  my $buf;
  while(($buf = $self->_readline()) && $buf !~ /<protein/){
    next;
  }
  $self->_pushback($buf);
}

sub next_feature {
  my $self =shift;
  my $buf;    #line buffer
  my $ok = 0; #true if there is another <protein/> record in stream
  my $record; #holds the record to be parsed and returned.

  #try to dump buffer from last record before moving on to next record
  my $f = $self->_shift_feature_buffer();
  if($f){
    return $f;
  }

  while(my $buf = $self->_readline()){
    $ok = 1 if $buf =~ m!<protein!;
    $record .= $buf;
    last if $buf =~ m!</protein>!;
  }
  return undef unless $ok;

  my $dom = $self->xml_parser->parse($record);


  my ($pNode) = $dom->findnodes('/protein');

  my @iNodes = $pNode->findnodes('/protein/interpro');

  foreach my $iNode (@iNodes){
    my @cNodes = $iNode->findnodes('classification');
    my @mNodes = $iNode->findnodes('match');

    #we don't handle these
    #my @nNodes = $iNode->findnodes('contains');
    #my @fNodes = $iNode->findnodes('found_in');

    foreach my $mNode (@mNodes){
      my @lNodes = $mNode->findnodes('location');
      foreach my $lNode (@lNodes){
        my $feature = Bio::SeqFeature::Annotated->new(
                                                      -start  => $lNode->getAttribute('start'),
                                                      -end    => $lNode->getAttribute('end'),
                                                      -score  => $lNode->getAttribute('score'),
                                                      -seq_id => $pNode->getAttribute('id'),
                                                     );

        my $t = Bio::Annotation::OntologyTerm->new(-identifier => 'SO:0000001', -name => 'region');
        $feature->add_Annotation('type',$t);

        my $d = Bio::Annotation::DBLink->new();
        $d->database($mNode->getAttribute('dbname'));
        $d->primary_id($mNode->getAttribute('id'));
        $d->optional_id($mNode->getAttribute('name'));
        $feature->annotation->add_Annotation('dblink',$d);

        my $s = Bio::Annotation::SimpleValue->new(-tagname => 'status', -value => $lNode->getAttribute('status'));
        $feature->annotation->add_Annotation($s);
        my $e = Bio::Annotation::SimpleValue->new(-tagname => 'evidence', -value => $lNode->getAttribute('evidence'));
        $feature->annotation->add_Annotation($e);

        foreach my $cNode (@cNodes){
          my $o = Bio::Annotation::OntologyTerm->new(-identifier => $cNode->getAttribute('id'));
          $feature->annotation->add_Annotation('ontology_term',$o);
        }

        $self->_push_feature_buffer($feature);
      }
    }
  }

  return $self->_shift_feature_buffer;
}

=head2 _push_feature_buffer()

 Usage   :
 Function:
 Returns : 
 Args    :


=cut

sub _push_feature_buffer {
  my ($self,$f) = @_;

  if(ref($f)){
    push @{ $self->{feature_buffer} }, $f;
  }
}

=head2 _shift_feature_buffer()

 Usage   :
 Function:
 Returns : 
 Args    :


=cut

sub _shift_feature_buffer {
  my ($self) = @_;
  return $self->{feature_buffer} ? shift @{ $self->{feature_buffer} } : undef;
}

=head2 xml_parser()

 Usage   : $obj->xml_parser($newval)
 Function: 
 Example : 
 Returns : value of xml_parser (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub xml_parser {
  my($self,$val) = @_;
  $self->{'xml_parser'} = $val if defined($val);
  return $self->{'xml_parser'};
}

1;
