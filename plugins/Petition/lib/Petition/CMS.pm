package Petition::CMS;

use strict;
use base qw( MT::App );

use constant LISTING_DATE_FORMAT      => '%b %e, %Y';
use constant LISTING_DATETIME_FORMAT  => '%b %e, %Y';
use constant LISTING_TIMESTAMP_FORMAT => "%Y-%m-%d %I:%M:%S%p";

use Petition::Question;
use Petition::Submission;

use Data::Dumper;

use MT::I18N qw( substr_text const length_text wrap_text encode_text
  break_up_text first_n_text guess_encoding );

use MT::Util qw( format_ts remove_html relative_date); 

sub plugin {
    return MT->component('Petition');
}

sub id { 'Petition_cms' }

sub edit_petition {
    my $app = shift;
    my %param;
    my $tmpl = 'edit_petition.tmpl';

    my $perms = $app->permissions;
    return $app->error($app->translate('Permission denied.')) unless
        $app->user->is_superuser() ||
        ($perms && ($perms->can_administer_blog ||
                    $perms->can_edit_all_posts));

    my $id = $app->param('id');

    if ($id) {
        $param{'id'} = $id;

        require Petition::Petition;
        # get the Quiz object
        my $petition = Petition::Petition->load( {id => $id} );
        $param{'petition_title'} = $petition->title();
        $param{'petition_description'} = $petition->description();
        $param{'petition_featured'} = 1 if $petition->featured();
        $param{'petition_salesforce_id'} = $petition->salesforce_id();
        $param{'petition_email_text'} = $petition->email_text();
        $param{'petition_email_subject'} = $petition->email_subject();
        $param{'petition_thank_you'} = $petition->thank_you();
        $param{'petition_active'} = 1; # if $petition->active();
        $param{'is_petition'} = 1;

        require Petition::Question;
        require Petition::Answer;

        my @questions = Petition::Question->load({ 
            petition_id => $petition->id(),
        },
        {
            sort => 'display_order', direction => 'ascend'
        });


        my @questions_loop;
        my $order = 1;

        my $question_do = 1;
        foreach my $question (@questions) {
            # get the answers for the question
            my @answers = Petition::Answer->load({
                question_id => $question->id(),
            },
            {
                sort => 'display_order', direction => 'ascend'
            });

            my @answers_loop;
            
            my $answer_do = 1;

            foreach my $answer (@answers) {
                push @answers_loop, { 
                    id => $answer->id(),
                    text => $answer->text(),
                    display_order => $answer_do++,
                    question_id => $answer->question_id(),
                };
            }

            if (@answers_loop < 6) {
                for (my $i = @answers_loop, my $j = 1; $i < 6; $i++, $j++) {
                    push @answers_loop, {
                        new => 1,
                        id => $j,
                        question_id => $question->id(),
                        display_order => $answer_do++,
                        text => '',
                    };
                }
            }
            
            push @questions_loop, {
                id => $question->id(),
                question => $question->question(),
                answers => \@answers_loop,
                display_order => $question_do++,
                required => $question->required(),
                validation => $question->validation(),
                type => $question->type(),
                slug => $question->slug(),
            };
        }

        # create the blank questions templates for additions
        if (@questions_loop < 10) {
            # we introduce $k so that we can introspect params with a loop
            # on save.
            for (my $i = @questions_loop, my $k = 1; $i < 10; $i++, $k++) {
                my @answers;
                for (my $j = 1; $j <= 6; $j++) {
                    push @answers, {
                        new => 1,
                        id => $j,
                        question_id => $k,
                        text => '',
                        display_order => $j,
                    };
                }

                push @questions_loop, {
                    new => 1,
                    id => $k,
                    question => '',
                    answers => \@answers,
                    display_order => $question_do++,
                };
            }
        }

        $param{'questions_loop'} = \@questions_loop;
    }
    else {
        $param{new_object} = 1;
        
        my @questions_loop;
        for (my $i = 1; $i <= 10; $i++) {
            my @answers;
            for (my $j = 1; $j <= 6; $j++) {
                push @answers, {
                    new => 1,
                    id => $j,
                    question_id => $i,
                    text => '',
                    display_order => $j,
                };
            }
            push @questions_loop, {
                new => 1,
                id => $i,
                question => '',
                answers => \@answers,
                display_order => $i
            };
        }
        $param{'questions_loop'} = \@questions_loop;
    }

    $param{saved} = 1 if $app->param('saved');
    $param{saved_added} = 1 if $app->param('saved_added');

    return $app->build_page( $tmpl, \%param );
}

sub save_petition {
    my $app = shift;

    my $id = $app->param('id');
    my $blog_id = $app->param('blog_id');

    my $perms = $app->permissions;
    return $app->error($app->translate('Permission denied.')) unless
        $app->user->is_superuser() ||
        ($perms && ($perms->can_administer_blog ||
                    $perms->can_edit_all_posts));

    if (defined($blog_id) && $blog_id ) {
        return $app->error( $app->translate("Invalid parameter") )
            unless ( $blog_id =~ m/\d+/ );
    }

    use Petition::Petition;
    use Petition::Question;
    use Petition::Answer;

    my $petition;
    
    # unfeature all the other petitions in the same blog
    if (defined($app->param('petition_featured')) && $app->param('petition_featured')) {
        my @featured = Petition::Petition->load({featured => 1, blog_id => $blog_id});
        foreach my $q (@featured) {
            $q->featured(0);
            $q->save();
        }
    }

    # validation.. there's gotta be a better way to do this... 
    if ($id) {
        $petition = Petition::Petition->load({id => $id});
        if (!$app->param('petition_title') ||
            $app->param('petition_title') =~ m/^\s*$/) {
            $petition->title('Default Petition Title');
        }
        else {
            $petition->title($app->param('petition_title'));
        }
        $petition->description($app->param('petition_description'));
        $petition->email_text($app->param('petition_email_text'));
        $petition->email_subject($app->param('petition_email_subject'));
        $petition->thank_you($app->param('petition_thank_you'));
        $petition->salesforce_id($app->param('petition_salesforce_id'));

        $petition->featured(defined($app->param('petition_featured')) ? 1: 0);
        $petition->active(1);
#        $petition->active(defined($app->param('petition_active')) ? 1: 0);

        $petition->save();

        # Update the questions
        my @questions = Petition::Question->load({petition_id => $id});
        my @questions_new;
        my @question_ids;
        foreach my $q (@questions) {
            next if !defined $app->param('question_' . $q->id());
            push @question_ids, $q->id();
            
            if ($app->param('question_' . $q->id()) !~ /^\s*$/) {
                $q->question($app->param('question_' . $q->id()));
                $q->petition_id($id);
                $q->display_order($app->param('display_order_' . $q->id()));
                $q->active(1);
                $q->type($app->param('type_' . $q->id()));
                $q->slug($app->param('slug_' . $q->id()));
                $q->validation($app->param('validation_' . $q->id()));
                if ($app->param('required_' . $q->id())) {
                    $q->required(1);
                }
                else {
                    $q->required(0);
                }

                $q->save();


            # if the question has_answers, we can do this. otherwise, we want to ignore them, or delete them
                if ($q->has_answers) {
                    # save and update
                    my @answers = Petition::Answer->load({question_id => $q->id});
                    foreach my $ans (@answers) {
                        my $prm = 'answer_' . $ans->question_id() . '_' . 
                            $ans->id();

                        if ($app->param($prm) !~ /^\s*$/) {
                            $ans->text($app->param($prm));
                            $ans->display_order($app->param('display_order_' . 
                                                            $ans->question_id() . 
                                                            '_' . $ans->id()));
                            $ans->save();
                        }
                        else {
                            $ans->remove();
                        }
                    }
                }
                else {
                    my @answers = Petition::Answer->load(
                        {question_id => $q->id});
                    foreach my $ans (@answers) {
                        $ans->remove();
                    }
                }

                # we're removing some questions if they no longer have text
                push @questions_new, $q;
            }
            else {
                # remove the question, it's gone.
                my @answers = Petition::Answer->load(
                    {question_id => $q->id});
                foreach my $ans (@answers) {
                    $ans->remove();
                }                
                $q->remove();
            }
        }

        # get the new answers if they exist for existing questions..
        foreach my $q (@questions_new) {
            if ($q->has_answers) {
                for (my $ai = 1; $ai < 6; $ai++) {
                    my $prm = 'new_answer_' . $q->id() . '_' . $ai;
                    if (defined($app->param($prm)) && 
                        $app->param($prm) !~ /^\s*$/) {
                        my $ans = Petition::Answer->new;
                        $ans->text($app->param($prm));
                        $ans->display_order($app->param('display_order_' . 
                                                        $q->id() . '_' . $ai));
                        $ans->question_id($q->id());
                        $ans->save();
                    }
                }
            }
        }

        $app->add_return_arg( 'saved' => 1 );
    }
    else {
        # save new.
        $petition = Petition::Petition->new;

        $petition->blog_id($blog_id);

        if (!$app->param('petition_title') ||
            $app->param('petition_title') =~ /^\s*$/) {
            $petition->title('Default Petition Title');
        }
        else {
            $petition->title($app->param('petition_title'));
        }
        $petition->description($app->param('petition_description'));
        $petition->featured(defined($app->param('petition_featured')) ? 1: 0);
        $petition->email_text($app->param('petition_email_text'));
        $petition->email_subject($app->param('petition_email_subject'));
        $petition->thank_you($app->param('petition_thank_you'));
        $petition->salesforce_id($app->param('petition_salesforce_id'));
        $petition->active(1);
#        $petition->active(defined($app->param('petition_active')) ? 1: 0);
        $petition->save();
        $id = $petition->id();
    }

    # there MIGHT be new questions. We know they are new by the new_ prefix
    # and the fact that the question id is sequential from 1

    my $qi = 1;
    while (defined($app->param('new_question_' . $qi))) {
        my $ai = 1;
        
        # if they supplied a question OK, otherwise go to the next.
        if ($app->param('new_question_' . $qi) !~ /^\s*$/) {
            my $question = Petition::Question->new();
            $question->petition_id($petition->id());
            $question->blog_id($blog_id);
            $question->question($app->param('new_question_' . $qi));

            $question->featured(0);
            $question->active(1);
            $question->display_order($app->param('display_order_' . $qi));
            $question->validation($app->param('new_validation_' . $qi));
            if ($app->param('new_required_' . $qi)) {
                $question->required(1);
            }
            else {
                $question->required(0);
            }
            $question->type($app->param('new_type_' . $qi));
            $question->slug($app->param('new_slug_' . $qi));

            $question->save();

            # we don't know the answer id that cooresponds to the index YET.
            # so, we've gotta save the answers and keep track of it.
                
            while (defined($app->param('new_answer_' . $qi . '_' . $ai))) {
                # create the answer stuff...
                my $prm = 'new_answer_' . $qi . '_' . $ai;
                if ($app->param($prm) && $prm !~ /^\s*$/) {
                    my $ans = Petition::Answer->new;
                    $ans->question_id($question->id());
                    $ans->display_order(
                        $app->param('display_order_' . $qi . '_' . $ai)
                        );
                    $ans->text($app->param($prm));
                    $ans->save();
                }
                $ai++;
            }
        }
        $qi++;
    }

    $app->add_return_arg( 'id' => $petition->id );
    $app->call_return;
}

sub list_petitions {
    my $app = shift;
    my $param = {};
    
    my $trim_length =
        $app->config('ShowIPInformation')
        ? const('DISPLAY_LENGTH_EDIT_COMMENT_TEXT_SHORT')
        : const('DISPLAY_LENGTH_EDIT_COMMENT_TEXT_LONG');
    my $author_max_len = const('DISPLAY_LENGTH_EDIT_COMMENT_AUTHOR');
    my $comment_short_len =
        const('DISPLAY_LENGTH_EDIT_COMMENT_TEXT_BREAK_UP_SHORT');
    my $comment_long_len =
        const('DISPLAY_LENGTH_EDIT_COMMENT_TEXT_BREAK_UP_LONG');
    my $title_max_len = const('DISPLAY_LENGTH_EDIT_COMMENT_TITLE');

    my ( %entries, %blogs, %cmntrs );
    my $perms = $app->permissions;
    my $user  = $app->user;

    return $app->error( $app->translate('Permission denied.') )
        unless $app->user->is_superuser()
        || (
            $perms
            && (   $perms->can_administer_blog
                   || $perms->can_edit_all_posts )
        );

    my $admin = $user->is_superuser
        || ( $perms && $perms->can_administer_blog );
    my $can_empty_junk = $admin
        || ( $perms && $perms->can_manage_feedback )
        ? 1 : 0;
    my $state_editable = $admin
        || ( $perms
             && ( $perms->can_publish_post
                  || $perms->can_edit_all_posts || $perms->can_manage_feedback ) )
        ? 1 : 0;

    my %submission_counts;
    my $iter = Petition::Submission->count_group_by(undef, 
                                         { group => ['petition_id'] });
    while (my ($cnt, $petid) = $iter->()) {
        $submission_counts{$petid} = $cnt;
    }

    my $code = sub {
        my ( $obj, $row ) = @_;

        # Petition column
        $row->{petition_id} = $obj->id();
        $row->{petition_salesforce_id} = $obj->salesforce_id();
        $row->{petition_short} =
            (substr_text( $obj->title(), 0, $trim_length )
              . ( length_text( $obj->title() ) > $trim_length ? "..." : "" ) );
        $row->{petition_short} =
            break_up_text( $row->{petition_short}, $comment_short_len );
        $row->{petition_long} = remove_html( $obj->description() );
        $row->{petition_long} =
            break_up_text( $row->{petition_long}, $comment_long_len );
        if ($submission_counts{$obj->id}) {
            $row->{petition_total_submissions} = $submission_counts{$obj->id};
        }
        else {
            $row->{petition_total_submissions} = 0;
        }

        # Date column
        my $blog = $blogs{ $obj->blog_id } ||= $obj->blog;
        if ( my $ts = $obj->created_on ) {
            $row->{created_on_time_formatted} =
                format_ts( LISTING_DATETIME_FORMAT, $ts, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{created_on_formatted} =
              format_ts( LISTING_DATE_FORMAT, $ts, $blog, $app->user ? $app->user->preferred_language : undef );

            $row->{created_on_relative} = relative_date( $ts, time, $blog );
        }

	 $row->{has_edit_access} = $state_editable;

        # Blog column
        if ($blog) {
            $row->{weblog_id}   = $blog->id;
            $row->{weblog_name} = $blog->name;
        }
        else {
            $row->{weblog_name} =
              '* ' . $app->translate('Orphaned comment') . ' *';
        }
    };

    my %param;

    my $blog_id = $app->param('blog_id');

    $param{feed_name} = $app->translate("Comments Activity Feed");
    $param{feed_url} =
      $app->make_feed_link( 'comment',
        $blog_id ? { blog_id => $blog_id } : undef );
    $param{filter_spam} =
      ( $app->param('filter_key') && $app->param('filter_key') eq 'spam' );
    $param{has_expanded_mode} = 1;
    $param{object_type}       = 'petitionpetition';
    $param{screen_id}         = 'list-petitions';
    $param{screen_class}      = 'list-petition';
    $param{search_label}      = $app->translate('Comments');
    $param{state_editable}    = $state_editable;
    $param{can_empty_junk}    = $can_empty_junk;

    $param{can_rebuild}       = $blog_id ? $perms->can_rebuild : 1;
	
    return $app->listing(
        {
            type   => 'petitionpetition',
            code   => $code,
            args   => { sort => 'created_on', direction => 'descend' },
            params => \%param,
        }
    );
}

sub export_petition_results {
    my $app = shift;

    my $perms = $app->permissions;
    my $user  = $app->user;

    return $app->error( $app->translate('Permission denied.') )
        unless $app->user->is_superuser()
        || (
            $perms
            && (   $perms->can_administer_blog
                   || $perms->can_edit_all_posts )
        );    

    my $petition_id = $app->param('id');
    my @output = ();
    if ($petition_id) {
        my @submissions = Petition::Submission->load(
            {petition_id => $petition_id},
            {sort => 'created_on', direction => 'descend'}
            );

        my @questions = Petition::Question->load(
            {petition_id => $petition_id},
            {sort => 'display_order', direction => 'ascend'}
            );

        my @qtext;
        push @qtext, '"Submission Date"';
        push @qtext, '"Petition ID"';
        foreach my $q (@questions) {
            my $q = $q->question();
            $q =~ s/\"/\\\"/g;
            push @qtext, '"' . $q . '"';
        }
        
        push @output, join(',', @qtext);

        foreach my $s (@submissions) {
            my %sm;
            my @row = ();
            
            $sm{created_on} = format_ts(LISTING_TIMESTAMP_FORMAT, 
                                        $s->created_on());
            $sm{petition_id} = $s->petition_id();
            $sm{data1} = $s->data1();
            $sm{data2} = $s->data2();
            $sm{data3} = $s->data3();
            $sm{data4} = $s->data4();
            $sm{data5} = $s->data5();
            $sm{data6} = $s->data6();
            $sm{data7} = $s->data7();
            $sm{data8} = $s->data8();
            $sm{data9} = $s->data9();
            $sm{data10} = $s->data10();

            for (1 .. 10) {
                $sm{'data' . $_} =~ s/\"/\\\"/g;
            }
            
            foreach my $f (qw(created_on petition_id data1 data2 data3
                              data4 data5 data6 data7 data8 data9 
                              data10)) {
                push @row, '"' . $sm{$f} . '"';
            }
            push @output, join ',', @row;
        }
    }

    my ($sec, $min, $hour, $mday, $mon, $year,
        $wday, $yday, $isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    $mon = "0$mon" if length $mon == 1;
    $mday = "0$mday" if length $mday == 1;
    my $filename = "petition_${petition_id}_$year$mon$mday.csv";
    $app->{no_print_body} = 1;
    $app->set_header('Content-Disposition', "attachment; filename=$filename");
    $app->send_http_header('text/csv');
    $app->print(join "\n", @output);
}

1;
