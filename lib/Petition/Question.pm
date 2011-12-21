package Petition::Question;

use strict;
use warnings;

use MT::Object;
use base qw( MT::Object );

use constant TEXTBOX    => 1;
use constant SHORTTEXT    => 2;
use constant LONGTEXT   => 3;

use constant RADIO      => 4;
use constant SELECT     => 5;
use constant CHECKBOXES   => 6;

use constant CHECKBOX   => 7;


# display_order could tie into drag and drop or something like that... 

__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer',
        'petition_id' => 'integer',
        'shortkey' => 'string(100)', # for export headers, etc, etc..
        'question' => 'text',
        'required' => 'boolean',
        'validation' => 'string(40)',
        'featured' => 'boolean',
        'active' => 'boolean',
        'type' => 'integer', 
        'slug' => 'string(40)',
        'display_order' => 'integer',
    },
    indexes => {
        'id' => 1,
        'blog_id' => 1,
        'featured' => 1,
    },
    defaults => {
        type => 1,
        active => 0,
    },
    primary_key => 'id',
    audit => 1,
    datasource => 'petitionquestion',
});

sub class_label {
    return MT->translate("Question");
}

sub class_label_plural {
    return MT->translate("Questions");
}

sub blog {
    my ($question) = @_;
    my $blog = $question->{__blog};

    unless ($blog) {
        my $blog_id = $question->blog_id;
        require MT::Blog;
        $blog = MT::Blog->load($blog_id) or
            return $question->error(MT->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));
        $question->{__blog} = $blog;
    }
    return $blog;
}

sub has_answers {
    my ($question) = @_;
    
    if ($question->type == Petition::Question::CHECKBOX ||
        $question->type == Petition::Question::SHORTTEXT ||
        $question->type == Petition::Question::TEXTBOX ||
        $question->type == Petition::Question::LONGTEXT) {
        return 0;
    }
    return 1;
}

1;
