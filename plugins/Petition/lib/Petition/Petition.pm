package Petition::Petition;

use strict;
use warnings;

use MT::Object;
use base qw( MT::Object MT::Scorable );

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer',
        'salesforce_id' => 'string(40)',
        'title' => 'text',
        'description' => 'text',
        'thank_you' => 'text',
        'email_text' => 'text',
        'email_subject' => 'text',
        'featured' => 'boolean',
        'active' => 'boolean',
        'captcha' => 'boolean',
    },
    indexes => {
        'id' => 1,
        'blog_id' => 1,
        'featured' => 1,
    },
    defaults => {
        featured => 0,
        active => 0,
    },
    primary_key => 'id',
    audit => 1,
    datasource => 'petitionpetition',
});

sub class_label {
    return MT->translate("Petition");
}

sub class_label_plural {
    return MT->translate("Petitions");
}

sub blog {
    0;
}

1;
