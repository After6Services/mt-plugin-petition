package Petition::SubmissionAnswer;

use strict;
use warnings;

use MT;
use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'submission_id' => 'integer',
        'answer_id' => 'integer',
        'is_correct' => 'boolean',
    },
    indexes => {
        'submission_id' => 1,
        'answer_id' => 1,
    },
    defaults => {
        'is_correct' => 0,
    }
    primary_key => 'id',
    audit => 1,
    datasource => 'Petitionsubmissionanswer',
});

sub class_label {
    return MT->translate("SubmissionAnswer");
}

sub class_label_plural {
    return MT->translate("SubmissionAnswers");
}
