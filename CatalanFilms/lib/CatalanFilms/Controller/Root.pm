﻿package CatalanFilms::Controller::Root;
use Moose;
use namespace::autoclean;

use JsonToHtml;
use Clone 'clone';
use CatalanFilmsTemplate;
use Unicode::Normalize;
use Encode qw(encode decode is_utf8);
use JSON;
use utf8;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=encoding utf-8

=head1 NAME

CatalanFilms::Controller::Root - Root Controller for CatalanFilms

=head1 DESCRIPTION

Catalan Films Catalogue 2015 generation from JSON to HTML

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index : Path("catalogue") {
    my ( $self, $c, $year, $category, $ppi ) = @_;

    my @film_names;
    $year = 2016 unless $year;
    $category = "all" unless $category;
    $ppi = 72 unless $ppi;
    if( $year == 2016 ) {
        $ppi = "custom";
    }
    my $A4_LANSCAPE = {
        72  => {
            width  => "1024px",
            height => "700px"
        },
        200 => {
            width  => "2339px",
            height => "1654px"
        },
        300 => {
            width  => "3508px",
            height => "2480px"
        },
        custom => {
            width  => "1280px",
            height => "800px"
        }
    };

    my $json_dir = $c->config->{json_dir};
    $json_dir =~ s/{year}/$year/g;
    my $images_dir = $c->config->{images_dir};
    $images_dir =~ s/{year}/$year/g;
    my $html_template_dir = $c->config->{html_template_dir};
    $html_template_dir =~ s/{year}/$year/g;

    my $jth = JsonToHtml->new(
        base_dir          => $c->config->{base_dir},
        json_dir          => $json_dir,
        images_dir        => $images_dir,
        config_dir        => $c->config->{config_dir},
        c                 => $c,
        image_cache       => 1,
        json_cache        => 0
    );

    my @categories;
    if( $category eq "all" ) {
        @categories = keys $c->config->{categories};
    } else {
        push(@categories, $category);
    }

    my $url;
    my $format_id;
    foreach my $cat (@categories) {
        $c->log->debug("Processant categoria " . $cat . "...");
        $url = $c->config->{categories}->{$cat}->{url};
        $url =~ s/{year}/$year/g;
        $jth->url($url);
        $jth->category($c->config->{categories}->{$cat}->{name});
        my $json_data = $jth->get_category_json_data();
        my $data = $jth->decode_json_data($json_data);
        my $config = $jth->get_category_config();
        my @fields = @{$config->{fields}};


        if( $year == 2015 ) {
            if( $cat eq "documentary" ) {
                # Change 5555 "Super Commuters" to Documentary Series
                $data->{films}->{5555}->{format} = "Television Documentaries Series";
                # Change 5553 "Ghost Towns" to Documentary Series
                $data->{films}->{5553}->{format} = "Television Documentaries Series";
                # Duplicate 4527 "Las Sin Sombrero" to Transmedia
                my $tmp_film = clone($data->{films}->{4527});
                $data->{films}->{4527_1} = $tmp_film;
                $data->{films}->{4527_1}->{format} = "Transmedia";
            } elsif( $cat eq "animation" ) {
                # Move 4584 "Old Folks' Tales. 2nd Season" to Animation TV Series
                # Only for catalogue 2015
                if( $year == 2015 ) {
                    $data->{films}->{4584}->{format} = "TV Series";
                }
            }
        } elsif( $year == 2016 ) {
            if( $cat eq "documentary" ) {
                # Copy "Old Folk's Tale/Contes d'avis 3rd season" From Animation to Documentary Transmedia
                $data->{films}->{5978} = decode_json q({"id":"5978","cast":[],"castArr":"","sinopsis":"<i>Old Folks' Tales<\/i> is an awarded collaborative documentary project about elders and grandchildren, and about turning orally told memories of childhood into animated stories. Stories both connected with personal experience and common history. But it's also an invitation to listen to the elders' voice, and search those wonderful stories of the past that help us understand who we are.","sound":["Digital 5.1"],"soundArr":"Digital 5.1","tech":["HD"],"techArr":"HD","video":"","duration":"14x5","format":"TV Series","arrFormat":["16"],"formatclass":"tv-series","title_original":"Cuentos de Viejos (III)","title_en":"Old Folks' Tales (III)","catalanspoke":"","upcoming":"upcoming","img":"cftv15509.tif","gender":["Documentary"],"genderArr":"Documentary","public":"General Audiences","vo":["Spanish"],"voArr":"Spanish","color":["Colour"],"year":"2015","companyinfo":{"id":"6750","country":"","name":"Piaggiodematei, Crossmedia Development"},"coproducers":[{"name":"Se\u00f1al Colombia","rol":"","country":"(Colombia)"},{"name":"Hierro Animaci\u00f3n","rol":"","country":"(Colombia)"}],"companysales":[],"filmtype":"Animation","director":["Marcelo Dematei","Carlos Smith","Laura Piaggio"],"directorStr":"Marcelo Dematei, Carlos Smith, Laura Piaggio","script":["Carolina Robledo Forero","Carlos Smith","Marcelo Dematei"],"scriptArr":"Carolina Robledo Forero<br \/>Carlos Smith<br \/>Marcelo Dematei","salesagent":"Contact producer","salesinfo":"","salesagents":{"name":"Contact producer","tel":"+34 932 002 500","email":"info@motionpic.com"},"image_linked":"http:\/\/gestor.catalanfilmsdb.cat\/imagenes\/produccions\/cftv15509.tif","link_produccio":"http:\/\/www.catalanfilmsdb.cat\/en\/f\/5978\/"});
                $data->{films}->{5978}->{format} = "Transmedia";
                delete $data->{films}->{6300};
            } elsif( $cat eq "animation" ) {
                # Duplicate 6132 "Troubling Monsters" to TV Series
                my $tmp_film = clone($data->{films}->{6132});
                $data->{films}->{6132_1} = $tmp_film;
                $data->{films}->{6132_1}->{format} = "TV Series";

                # Duplicate 6169 "My Preschool Monsters " to Apps
                my $tmp_film = clone($data->{films}->{6169});
                $data->{films}->{6169_1} = $tmp_film;
                $data->{films}->{6169_1}->{format} = "Other Platforms";
            }
        }

        my @html;
        my $attrs = {};
        my $cf_template = CatalanFilmsTemplate->new(
            include_path  => $c->config->{base_dir} . $html_template_dir,
            template_file => $c->config->{categories}->{$cat}->{name} . '.tt.html'
        );
        # Sort films A-Z for each format section
        my @filmsSortByFormat = sort(
        {
            my $a_format = $data->{films}->{$a}->{format};
            my $b_format = $data->{films}->{$b}->{format};
            my $a_id = $data->{films}->{$a}->{id};
            my $b_id = $data->{films}->{$b}->{id};
            if( $a_format eq "Fiction - Webseries" ) {
                $a_format = "Web Series";
            }
            if( $b_format eq "Fiction - Webseries" ) {
                $b_format = "Web Series";
            }
            if( $a_format eq "Anmation - Webseries" ) {
                $a_format = "Web Series";
            }
            if( $b_format eq "Anmation - Webseries" ) {
                $b_format = "Web Series";
            }
            if(
                $cat eq "animation"
                and
                $a_format eq "Other Platforms"
            ) {
                $a_format = "ZApps";
            }
            if(
                $cat eq "animation"
                and
                $b_format eq "Other Platforms"
            ) {
                $b_format = "ZApps";
            }
            if( $cat eq "documentary" and ($a_format eq "Other Platforms" or $a_format eq "VDocumental - Webdocs") ) {
                $a_format = "Transmedia";
            }
            if( $cat eq "documentary" and ($b_format eq "Other Platforms" or $b_format eq "VDocumental - Webdocs") ) {
                $b_format = "Transmedia";
            }

            $a_format cmp $b_format
            or
            NFKD(lc($data->{films}->{$a}->{upcoming})) cmp NFKD(lc($data->{films}->{$b}->{upcoming}))
            or
            NFKD(lc($data->{films}->{$a}->{title_en})) cmp NFKD(lc($data->{films}->{$b}->{title_en}))
        } keys %{$data->{films}} );

        foreach my $item (@filmsSortByFormat) {
            my $current_format_id = lc($data->{films}->{$item}->{format});
            $attrs->{category} = $cat;
            if(
                $cat eq "formats"
                and
                (
                    $current_format_id eq "fiction - webseries"
                    or
                    $current_format_id eq "anmation - webseries"
                )
            ) {
            } else {
                if(
                    $cat eq "documentary"
                    and
                    ( $current_format_id eq "other platforms" or $current_format_id eq "vdocumental - webdocs" )
                ) {
                    $current_format_id = "transmedia";
                }
                if(
                    $cat eq "documentary"
                    and
                    ( $current_format_id eq "television documentaries series" )
                ) {
                    $current_format_id = "televisiondocumentariesseries";
                    $data->{films}->{$item}->{format} = "Documentary Series";
                }
                if(
                    $cat eq "animation"
                    and
                    $current_format_id eq "other platforms"
                ) {
                    $current_format_id = "apps";
                }
                if(
                    $cat eq "animation"
                    and
                    $current_format_id eq "anmation - webseries"
                ) {
                    $current_format_id = "webseries";
                }
                $current_format_id =~ s/ //gmi;
                $current_format_id = $cat . "-" . $current_format_id;
                if( !$format_id || $format_id ne $current_format_id ) {
                    $format_id = $current_format_id;
                    $attrs->{format_id} = $current_format_id;
                }
                elsif ( $format_id eq $current_format_id ) {
                    $attrs->{format_id} = "";
                }
                $attrs->{current_format_id} = $current_format_id;
                foreach my $field (@fields) {
                    if( $field->{output_name} ) {
                        $attrs->{$field->{output_name}} = $jth->process_item_field($data->{films}->{$item}, $field);
                    } else {
                        $attrs->{$field->{name}} = $jth->process_item_field($data->{films}->{$item}, $field);
                    }
                }
                push(@html, $cf_template->process($attrs));
                push(@film_names, {
                    "title" => $attrs->{title_en},
                    "id"    => $attrs->{id}
                });
            }
        }
        $c->stash->{$cat} = join("", @html);
    }

    sub group_by_alphabet {
        my ( $self, $key, @names ) = @_;
        my $group;
        foreach my $film (@names) {
            if( !is_utf8($film->{$key}) ) {
                $film->{$key} = encode("utf-8",$film->{$key});
            }
            $film->{$key} =~ /^(.{1}).*/gmi;
            my $first_letter = lc(NFKD($1));
            $first_letter =~ s/\p{NonspacingMark}//g;
            $group->{$first_letter} = () unless exists $group->{$first_letter};
            push(@{$group->{$first_letter}}, $film);

        }
        return $group;
    }

    # Sales
    $url = $c->config->{sales}->{url};
    $url =~ s/{year}/$year/g;
    $jth->url($url);
    $jth->category($c->config->{sales}->{name});
    my $json_data = $jth->get_sales_producers_json_data();
    my $sales_data = $jth->decode_json_data($json_data);
#    $c->log->debug("Sales Data " . scalar(keys %{$sales_data}));

    # Producers
    $url = $c->config->{producers}->{url};
    $url =~ s/{year}/$year/g;
    $jth->url($url);
    $jth->category($c->config->{producers}->{name});
    $json_data = $jth->get_sales_producers_json_data();
    my $producers_data = $jth->decode_json_data($json_data);
#    $c->log->debug("producers_data " . scalar(keys %{$producers_data}));

#    foreach my $key (keys %{$sales_data}) {
#        if( exists $producers_data->{$key} ) {
#            $c->log->debug("Key $key exists");
#        }
#    }

    my $sales_producers_data = ($sales_data, $producers_data);
    # Sort sales & producers A-Z
    my @sales_producers = sort(
    {
        NFKD(lc($sales_producers_data->{$a}->{empresa})) cmp NFKD(lc($sales_producers_data->{$b}->{empresa}))
    } keys %{$sales_producers_data} );

    $c->log->debug("Total Sales & Producers: " . scalar(@sales_producers));
    my @sales_producers_list;
    foreach my $key (@sales_producers) {
        push(@sales_producers_list, $sales_producers_data->{$key});
    }
    my $sales_producers_index_template = CatalanFilmsTemplate->new(
        include_path  => $c->config->{base_dir} . $html_template_dir,
        template_file => 'sales_producers_index.tt.html'
    );
    $c->stash->{sales_producers_index} = $sales_producers_index_template->process({
        sales_producers_names => $self->group_by_alphabet("empresa", @sales_producers_list)
    });

    # Sort all films in alphabetical order and group by alphabet
    my @sorted_film_names = sort({ NFKD(lc($a->{title})) cmp NFKD(lc($b->{title})) } @film_names);
    my $title_index_template = CatalanFilmsTemplate->new(
        include_path  => $c->config->{base_dir} . $html_template_dir,
        template_file => 'title_index.tt.html'
    );
    $c->stash->{title_index} = $title_index_template->process({
        grouped_film_names => $self->group_by_alphabet("title", @sorted_film_names)
    });

    $c->stash->{template} = "catalan_films_catalogue_$year.tt2";
    $c->log->debug("Year " . $year);
    $c->stash->{year} = $year;
    $c->stash->{resources_version} = "13";
    $c->stash->{page_width} = $A4_LANSCAPE->{$ppi}->{width};
    $c->stash->{page_height} = $A4_LANSCAPE->{$ppi}->{height}
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Marc Perez Castells,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
