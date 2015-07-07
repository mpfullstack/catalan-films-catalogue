package CatalanFilmsTemplate;

use Moose;
use Template;
use Encode qw(encode decode);
use utf8;

has 'include_path'  => (is => 'rw', isa => 'Str');
has 'template_file' => (is => 'rw', isa => 'Str');
has 'start_tag'     => (is => 'rw', isa => 'Str', default => '%%');
has 'end_tag'       => (is => 'rw', isa => 'Str', default => '%%');
has 'encoding'      => (is => 'rw', isa => 'Str', default => 'utf-8');

sub process {
	my ( $self, $data ) = @_;

	# Config options
	my $config = {
		INCLUDE_PATH => $self->include_path,
		INTERPOLATE  => 1,
        ENCODING     => $self->encoding,
		EVAL_PERL    => 1,
		START_TAG    => $self->start_tag,
		END_TAG      => $self->end_tag,
        render_die => 1
	};

	my $output;
    my $template = Template->new($config);
	$template->process($self->template_file, $data, \$output) || die $template->error(), "\n";

    #return encode("utf8",$output);
    return $output;
}

return 1;
