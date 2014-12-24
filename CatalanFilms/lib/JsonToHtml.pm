package JsonToHtml;

use Moose;
use Imager;
use Image::Size;
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
has 'json_cache'        => (is => 'rw', isa => 'Bool', default => 0);
has 'image_cache'       => (is => 'rw', isa => 'Bool', default => 1);
has 'file'              => (is => 'ro', isa => 'Object', default => sub { return File::Util->new() }); 
has 'hs'                => (is => 'ro', isa => 'Object', default => sub { return HTML::Strip->new() }); 
has 'c'                 => (is => 'ro', isa => 'Object'); 
has 'json_dir'          => (is => 'rw', isa => 'Str');
has 'images_dir'        => (is => 'rw', isa => 'Str');
has 'html_data_dir'     => (is => 'rw', isa => 'Str');
has 'html_tempalte_dir' => (is => 'rw', isa => 'Str');
has 'config_dir'        => (is => 'rw', isa => 'Str');

sub get_category_json_data {
    my ( $self ) = @_;
    $self->c->log->debug("Llegint categoria " . $self->category . "...");
    my $data;
    my $filedir = $self->json_dir . $self->file->SL . $self->category.".json";
    $self->file->make_dir($self->json_dir, 0755, '--if-not-exists');
    $self->file->make_dir($self->images_dir . $self->file->SL . $self->category, 0755, '--if-not-exists');
    if( $self->json_cache and $self->file->existent($filedir) ) {
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
    my ( $self, $item, $field ) = @_;

    my $cleanvalue;
    if( $field->{type} ) {
        if( $field->{type} eq 'list' ) {
            $cleanvalue = $self->hs->parse(join(', ', @{$item->{$field->{name}}}));
        } elsif( $field->{type} eq 'list_br' ) {
            $cleanvalue = $item->{$field->{name}};
            $cleanvalue =~ s/<br \/>/, /gmi
        } elsif( $field->{type} eq 'image' ) {
            my $image_url = $item->{$field->{name}};
            $image_url =~ /^.+\.(.+)$/gmi;
            my $extension = $1;
            if( 
                !$self->file->existent(
                    $self->images_dir.
                    $self->file->SL.
                    $self->category.
                    $self->file->SL.
                    $item->{id} . "." . $extension
                ) 
            ) {
                my $image = get($image_url);
                $self->file->write_file(
                  'file' => $self->images_dir . $self->file->SL . $self->category . $self->file->SL . $item->{id} . "." . $extension,
                  'content' => $image
                );
            }
            if( !$self->image_cache 
                || 
                !$self->file->existent(
                    $self->images_dir.
                    $self->file->SL.
                    $self->category.
                    $self->file->SL.
                    $item->{id} . "_thumb." . $extension
                ) 
            ) {                
                $self->scaleImage(
                    $self->images_dir . $self->file->SL . $self->category . $self->file->SL . $item->{id} . "." . $extension,
                    400
                );
            }
            $cleanvalue = $self->c->uri_for('static/images/'. $self->category . '/' . $item->{id} . "_thumb." . $extension);
        }
    } else {
        $cleanvalue = $self->hs->parse($item->{$field->{name}});        
    }
    
    $cleanvalue =~ s///gmi;
    $cleanvalue = $self->trim($cleanvalue);

    if( is_utf8($cleanvalue) ) {
        return $cleanvalue;
    } else {
        return decode($self->encoding, $cleanvalue);
    }
}

sub scaleImage {
    my ( $self, $image, $x, $y ) = @_;

    $x = "" unless $x;
    $y = "" unless $y;

    $image =~ /^(\/.+\/)(.+)?\.(.+)$/;
	my $scaled_image = $1.$2.'_thumb.'.$3;

    my $imager = Imager->new();		
    $imager->read( file => $image ) or die "Cannot read: $image ".$imager->errstr();
    if(
        ( !$y && $x < $imager->getwidth() ) 
        || 
        ( !$x && $y < $imager->getheight() ) 
        || 
        ( $x && $y && ( $x < $imager->getwidth() || $y < $imager->getheight() ) ) 
    ) {
        my $new_image = $imager->scale( xpixels => $x, ypixels => $y, type => 'min', qtype => 'normal' ) or die $image." ".$imager->errstr();
        $new_image->write( file => $scaled_image, type => undef );
    }
}

sub trim {
    my ( $self, $str ) = @_;

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    return $str;
}

return 1;

