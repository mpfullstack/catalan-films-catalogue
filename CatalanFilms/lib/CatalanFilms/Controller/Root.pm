package CatalanFilms::Controller::Root;
use Moose;
use namespace::autoclean;

use JsonToHtml;
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

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $html = 
    '<!DOCTYPE html>'.
    '<html>'.
    '<head>'.
    '</head>'.
    '<body>'.
    '<p>Hello Catalan Films!</p>'.
    '<body>'.
    '</html>';

    my $jth = JsonToHtml->new(
        json_dir => $c->config->{base_dir} . $c->config->{json_dir},
        html_data_dir => $c->config->{base_dir} . $c->config->{html_dir},
        html_template_dir =>$c->config->{base_dir} . $c->config->{html_template_dir},
        config_dir => $c->config->{base_dir} . $c->config->{config_dir},
        c        => $c
    );

#    $c->log->debug("Category URL " . $c->config->{categories}->{fiction}->{url});
#    $c->log->debug("Category Name " . $c->config->{categories}->{fiction}->{name});

    # Fiction category
    $jth->url($c->config->{categories}->{fiction}->{url});
    $jth->category($c->config->{categories}->{fiction}->{name});
    my $json_data = $jth->get_category_json_data(
        $c->config->{categories}->{fiction}->{url},
        $c->config->{categories}->{fiction}->{name}
    );
    my $data = $jth->decode_json_data($json_data);
    my $config = $jth->get_category_config();
    my @fields = @{$config->{fields}};

    $c->response->body( $html );
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
