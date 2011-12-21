package Petition::Submission;

use strict;
use warnings;
use MT;
use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'petition_id' => 'integer',
        'data1' => 'text',
        'data2' => 'text',
        'data3' => 'text',
        'data4' => 'text',
        'data5' => 'text',
        'data6' => 'text',
        'data7' => 'text',
        'data8' => 'text',
        'data9' => 'text',
        'data10' => 'text',
    },
    indexes => {
        'id' => 1,
        'petition_id' => 1,
    },
    primary_key => 'id',
    audit => 1,
    datasource => 'petitionsubmission',
});

sub class_label {
    return MT->translate("Submission");
}

sub class_label_plural {
    return MT->translate("Submissions");
}


1;
