package JsonToHtml;

use Moose;
use Cwd;
use File::Util;
use JSON;
use LWP::Simple;
use HTML::Entities;
use HTML::Strip;
use Data::Dumper;
use DateTime;
use Encode qw(encode decode is_utf8);
use utf8;

has 'url'               => (is => 'rw', isa => 'Str');
has 'category'          => (is => 'rw', isa => 'Str');
has 'encoding'          => (is => 'rw', isa => 'Str', default => 'utf-8');
has 'cache'             => (is => 'rw', isa => 'Bool', default => 0);
has 'file'              => (is => 'ro', isa => 'Object', default => sub { return File::Util->new() }); 
has 'hs'                => (is => 'ro', isa => 'Object', default => sub { return HTML::Strip->new() }); 
has 'c'                 => (is => 'ro', isa => 'Object'); 
has 'json_dir'          => (is => 'rw', isa => 'Str');
has 'html_data_dir'     => (is => 'rw', isa => 'Str');
has 'html_tempalte_dir' => (is => 'rw', isa => 'Str');
has 'config_dir'        => (is => 'rw', isa => 'Str');

sub get_category_json_data {
    my ( $self ) = @_;
    $self->c->log->debug("Llegint categoria " . $self->category . "...");
    my $data;
    my $filedir = $self->json_dir . $self->file->SL . $self->category.".json";
    $self->file->make_dir($self->json_dir, 0755, '--if-not-exists');
    if( $self->cache and $self->file->existent($filedir) ) {
        $data = $self->file->load_file($filedir);
    } else {
        $data = get($self->url);
        $self->file->write_file(
            'file'    => $filedir,
            'bitmask' => 0755,
            'content' => $data,
            'binmode' => 'utf8'
        );
    }
    $self->c->log->debug("FET");
    return $data;
}

sub decode_json_data {
    my ( $self, $json_data ) = @_;
    $self->c->log->debug("Decodificant dades JSON");
    my $data = decode_json $json_data;
    $self->c->log->debug("FET.");
    return $data;
}

sub get_category_config {
    my ( $self ) = @_;
    $self->c->log->debug("Obtenint configuració categoria " . $self->category . "...");
    my $filedir = $self->config_dir . $self->file->SL . $self->category.".json";
    if( $self->file->existent($filedir) ) {
        my $config_data = $self->file->load_file($filedir);
        $self->c->log->debug("FET.");
        return decode_json $config_data;
    }
    die "no config file";
}

sub process_item_field {
    my ($self, $item, $field) = @_;

    my $cleanvalue;
    if( $field->{type} ) {
        if( $field->{type} eq 'list' ) {
            $cleanvalue = $self->hs->parse(join(', ', @{$item->{$field->{name}}}));
        } elsif( $field->{type} eq 'list_br' ) {
            $cleanvalue = $item->{$field->{name}};
            $cleanvalue =~ s/<br \/>/, /gmi
        } elsif( $field->{type} eq 'image' ) {
            #TODO: Check modified date and compare with existing
#            my $image = get($item->{$field->{name});
            my $image = "http://clients.welvisolutions.com/canalneumatico/boletin/BoletinDestacado2.png";            
            $self->file->make_dir("images" . $self->file->SL . $self->category, 0755, '--if-not-exists');
            my $cwd = getcwd();
            $self->file->write_file(
              'file' => "images" . $self->file->SL . $self->category . $self->file->SL . $item->{id} . ".png",
              'content' => $image
            );
            return $cwd . $self->file->SL . "images" . $self->file->SL . $self->category . $self->file->SL . $item->{id} . ".png";
        }
    } else {
        $cleanvalue = $self->hs->parse($item->{$field->{name}});
    }
    
    $cleanvalue =~ s///gmi;
    $cleanvalue =~ s/"/""/gmi;
    $cleanvalue = $self->trim($cleanvalue);

    if( is_utf8($cleanvalue) ) {
        return $cleanvalue;
    } else {
        return decode($self->encoding, $cleanvalue);
    }
}

sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

return 1;

