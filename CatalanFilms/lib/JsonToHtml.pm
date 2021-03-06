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
has 'hs'                => (is => 'ro', isa => 'Object', default => sub { return HTML::Strip->new(striptags => [ 'br' ]) });
has 'c'                 => (is => 'ro', isa => 'Object');
has 'base_dir'          => (is => 'rw', isa => 'Str');
has 'json_dir'          => (is => 'rw', isa => 'Str');
has 'images_dir'        => (is => 'rw', isa => 'Str');
has 'html_data_dir'     => (is => 'rw', isa => 'Str');
has 'html_template_dir' => (is => 'rw', isa => 'Str');
has 'config_dir'        => (is => 'rw', isa => 'Str');

sub get_category_json_data {
    my ( $self ) = @_;
    $self->c->log->debug("Llegint categoria " . $self->category . "...");
    my $data;
    my $filedir = $self->base_dir . $self->json_dir . $self->file->SL . $self->category.".json";
    $self->file->make_dir($self->base_dir . $self->json_dir, 0755, '--if-not-exists');
    $self->file->make_dir($self->base_dir . $self->images_dir . $self->file->SL . $self->category, 0755, '--if-not-exists');
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

sub get_sales_producers_json_data {
    my ( $self ) = @_;
    $self->c->log->debug("Llegint categoria " . $self->category . "...");
    my $data;
    my $filedir = $self->base_dir . $self->json_dir . $self->file->SL . $self->category.".json";
    $self->file->make_dir($self->base_dir . $self->json_dir, 0755, '--if-not-exists');
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
        if( $field->{type} eq 'list' and $item->{$field->{name}} ) {
            $cleanvalue = $self->hs->parse(join(', ', @{$item->{$field->{name}}}));
        } elsif( $field->{type} eq 'list_br' ) {
            $cleanvalue = $item->{$field->{name}};
            $cleanvalue =~ s/<br \/>/, /gmi
        } elsif( $field->{type} eq 'list_by_key' ) {
            my $key = $field->{key};
            my $output_name = $field->{output_name};
            my @tmp_list = @{$item->{$field->{name}}};
            my @values;
            foreach my $item ( @tmp_list ) {
                if( $item->{$key} ) {
                    if( $field->{name} eq "coproducers" and $output_name and $output_name eq "coproducers_rol" ) {
                        push(@values, $self->trim($item->{$key})) unless !$item->{rol};
                    } elsif( $field->{name} eq "coproducers" ) {
                        push(@values, $self->trim($item->{$key})) unless $item->{rol};
                    } else {
                        push(@values, $self->trim($item->{$key}));
                    }
                }
            }
            if( scalar(@values) > 0 ) {
                $cleanvalue = $self->hs->parse(join(', ', @values));
            } else {
                $cleanvalue = "";
            }
        } elsif( $field->{type} eq 'hash_by_key' ) {
            my $key = $field->{key};
            if( $item->{$field->{name}} ) {
                $cleanvalue = $item->{$field->{name}}->{$key};
            } else {
                $cleanvalue = "";
            }
        } elsif( $field->{type} eq 'image' ) {
            my $image_url = $item->{$field->{name}};
            $image_url =~ /^.+\.(.+)$/gmi;
            my $extension = $1;
            if(
                !$self->file->existent(
                    $self->base_dir . $self->images_dir.
                    $self->file->SL.
                    $self->category.
                    $self->file->SL.
                    $item->{id} . "." . $extension
                )
            ) {
                my $image = get($image_url);
                $self->file->write_file(
                  'file' => $self->base_dir . $self->images_dir . $self->file->SL . $self->category . $self->file->SL . $item->{id} . "." . $extension,
                  'content' => $image
                );
            }
            if( !$self->image_cache
                ||
                !$self->file->existent(
                    $self->base_dir . $self->images_dir.
                    $self->file->SL.
                    $self->category.
                    $self->file->SL.
                    $item->{id} . "_thumb.jpg"
                )
            ) {
                $self->scaleImage(
                    $self->base_dir . $self->images_dir . $self->file->SL . $self->category . $self->file->SL . $item->{id} . '.' . $extension,
                    560
                );
            }
            $cleanvalue = $self->c->uri_for($self->images_dir . '/' . $self->category . '/' . $item->{id} . '_thumb.jpg');
        }
    } else {
#        $cleanvalue = $self->hs->parse($item->{$field->{name}});
        if( $field->{name} eq "format" ) {
            if( $item->{$field->{name}} eq "Fiction - Webseries" ) {
                $cleanvalue = "Web Series";
            } elsif(
                $self->category eq "documentary"
                and
                (
                    $item->{$field->{name}} eq "Other Platforms"
                    or
                    $item->{$field->{name}} eq "VDocumental - Webdocs"
                )
            ) {
                $cleanvalue = "Transmedia";
            } elsif(
                $self->category eq "animation"
                and
                $item->{$field->{name}} eq "Other Platforms"
            ) {
                $cleanvalue = "Apps";
            } elsif(
                $self->category eq "animation"
                and
                $item->{$field->{name}} eq "Anmation - Webseries"
            ) {
                $cleanvalue = "Web Series";
            } else {
                $cleanvalue = $item->{$field->{name}};
            }
        } else {
            $cleanvalue = $item->{$field->{name}};
        }
    }

    $cleanvalue =~ s/<i>Farselona<i>/<em>Farselona<\/em>/gmi;
    $cleanvalue =~ s/<i>/<em>/gmi;
    $cleanvalue =~ s/<\/i>/<\/em>/gmi;

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
	my $scaled_image = $1.$2.'_thumb.jpg';

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
        $new_image->write( file => $scaled_image, jpegquality => 90 );
    }
}

sub trim {
    my ( $self, $str ) = @_;

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    return $str;
}

return 1;

