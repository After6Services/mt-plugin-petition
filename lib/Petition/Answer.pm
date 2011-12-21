package Petition::Answer;

use strict;
use warnings;

use MT::Object;

use base qw( MT::Object );

# display_order could tie into drag and drop or something like that... 

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'question_id' => 'integer',
        'text' => 'text',
        'display_order' => 'integer',
    },
    indexes => {
        'id' => 1,
        'question_id' => 1,
    },
    primary_key => 'id',
    audit => 1,
    datasource => 'petitionanswer',
});

1;

