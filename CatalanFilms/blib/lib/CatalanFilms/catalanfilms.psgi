use strict;
use warnings;

use CatalanFilms;

my $app = CatalanFilms->apply_default_middlewares(CatalanFilms->psgi_app);
$app;

