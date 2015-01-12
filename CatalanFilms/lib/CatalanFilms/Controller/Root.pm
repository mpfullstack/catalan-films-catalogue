package CatalanFilms::Controller::Root;
use Moose;
use namespace::autoclean;

use JsonToHtml;
use CatalanFilmsTemplate;
use Unicode::Normalize;
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

sub index : Path("catalogue2015") {
    my ( $self, $c, $category, $ppi ) = @_;

    my @films;
    $category = "all" unless $category;
    $ppi = 72 unless $ppi;
    my $A4_LANSCAPE = {
        72  => {
            width  => "1024px",
            height => "700px"
#            width  => "842px",
#            height => "595px"
        },
        200 => {
            width  => "2339px",
            height => "1654px"
        },
        300 => {
            width  => "3508px",
            height => "2480px"
        }
    };
    
    my $jth = JsonToHtml->new(
        json_dir          => $c->config->{base_dir} . $c->config->{json_dir},
        images_dir        => $c->config->{base_dir} . $c->config->{images_dir},
        html_data_dir     => $c->config->{base_dir} . $c->config->{html_data_dir},
        html_template_dir => $c->config->{base_dir} . $c->config->{html_template_dir},
        config_dir        => $c->config->{base_dir} . $c->config->{config_dir},
        c                 => $c,
        image_cache       => 1
    );

    my @categories;
    if( $category eq "all" ) {
        @categories = keys $c->config->{categories};
    } else {
        push(@categories, $category);
    }
    
    foreach my $cat (@categories) {
        $c->log->debug("Processant categoria " . $cat . "...");
        $jth->url($c->config->{categories}->{$cat}->{url});
        $jth->category($c->config->{categories}->{$cat}->{name});
        my $json_data = $jth->get_category_json_data(
            $c->config->{categories}->{$cat}->{url},
            $c->config->{categories}->{$cat}->{name}
        );
        my $data = $jth->decode_json_data($json_data);
        my $config = $jth->get_category_config();
        my @fields = @{$config->{fields}};

        my @html;
        my $attrs = {};
        my $cf_template = CatalanFilmsTemplate->new(
            include_path  => $c->config->{base_dir} . $c->config->{html_template_dir},
            template_file => $c->config->{categories}->{$cat}->{name} . '.tt.html'
        );
        # Sort films A-Z for each format section
        my @filmsSortByFormat = sort( 
            {
                $data->{films}->{$a}->{format} cmp $data->{films}->{$b}->{format} 
                or
                NFKD(lc($data->{films}->{$a}->{upcoming})) cmp NFKD(lc($data->{films}->{$b}->{upcoming}))
                or
                NFKD(lc($data->{films}->{$a}->{title_en})) cmp NFKD(lc($data->{films}->{$b}->{title_en}))
            } keys %{$data->{films}} );

        foreach my $item (@filmsSortByFormat) {
            foreach my $field (@fields) {
                if( $field->{output_name} ) {
                    $attrs->{$field->{output_name}} = $jth->process_item_field($data->{films}->{$item}, $field);
                } else {
                    $attrs->{$field->{name}} = $jth->process_item_field($data->{films}->{$item}, $field);
                }
            }
            push(@html, $cf_template->process($attrs));
            push(@films, $attrs->{title_en});
        }
        $c->stash->{$cat} = join("", @html);
    }

    # Sort all films in alphabetical order
    $c->stash->{films} = sort({ NFKD(lc($a)) cmp NFKD(lc($b)) } @films);
    $c->stash->{template} = "catalan_films_catalogue_2015.tt2";
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
