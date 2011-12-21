package Petition;

use base 'MT::App';

use Petition::Petition;
use Petition::Submission;
use MT::Util qw( is_valid_email );
use Fcntl ':flock';

use strict;

sub init {
    my $app = shift;

    $app->SUPER::init(@_);
    $app->add_methods(
        default => \&process_submission,
        petition_widget => \&process_widget_submission,
        );
	#$app->{default_mode} = 'default';
    $app;
}

sub process_submission {
    my $app = shift;

    my $petition_id = $app->{query}->param('petition_id');
    my $petition;

    if ($petition_id) {
        $petition = Petition::Petition->load({ id => $petition_id });
    }
    else {
        $petition = Petition::Petition->load({ featured => 1 });
        $petition_id = $petition->id;
    }

    if (!$petition) {
        return "<p>No petition found</p>";
    }

    my $return_to_url = sanitize_return($app, $app->param('return_to'));
    my $error_return_url = sanitize_return($app, $app->param('error_return_to'));

    # where to go in case of success
    my $return_to_seperator = '?';
    if ($return_to_url =~ /\?/) {
        $return_to_seperator = '&';
    }

    # where to go in case of errors.
    my $error_to_seperator = '?';
    if ($error_return_url =~ /\?/) {
        $error_to_seperator = '&';
    }

    if (!validate_captcha($app, $petition)) {
        $app->redirect($error_return_url . 
                       $error_to_seperator . 
                       "captcha_error=1");
        return;
    }

    # go forth and process young one.
    return _process($app, $petition, $return_to_url, $return_to_seperator, 
                    $error_return_url, $error_to_seperator);    
}


sub process_widget_submission {
    my $app = shift;

    my $petition_id = $app->{query}->param('petition_id');
    my $petition;

    if ($petition_id) {
        $petition = Petition::Petition->load({ id => $petition_id });
    }
    else {
        $petition = Petition::Petition->load({ featured => 1 });
        $petition_id = $petition->id;
    }

    if (!$petition) {
        return "<p>No petition found</p>";
    }

    my $return_to_url = sanitize_return($app, $app->param('return_to'));
    my $error_return_url = sanitize_return($app, $app->param('error_return_to'));

    # where to go in case of success
    my $return_to_seperator = '?';
    if ($return_to_url =~ /\?/) {
        $return_to_seperator = '&';
    }

    # where to go in case of errors.
    my $error_to_seperator = '?';
    if ($error_return_url =~ /\?/) {
        $error_to_seperator = '&';
    }


    # If the anti-spam tests fail, we'll ignore, but pretend it worked.
    my $just_ignore = 0;

    # 1. beacon should always be 1. If it's not, it's spam.
    if ($app->param('beacon') ne "1") {
        $just_ignore = 1;
    }

    # 2. challenge should always be the day portion of today's date +/- 1, 
    #    for timezone differences
    my @time = localtime(time);
    my @time2 = localtime(time - (86400 * 1));
    my @time3 = localtime(time + (86400 * 1));
    my $challenge = $app->param('challenge');
    if ($challenge ne $time[3] || 
        $challenge ne $time[3] || 
        $challenge ne $time[3]) {
        $just_ignore = 1;
    }

    if ($just_ignore) {
        # redirect them to the thank you page and pretend they won!
        my $redirect_query_params = 'success=1';
        # successful redirect
        $app->redirect($return_to_url . $return_to_seperator . $redirect_query_params);
    }

    return _process($app, $petition, $return_to_url, $return_to_seperator, 
                    $error_return_url, $error_to_seperator);
}

sub _process {
    my ($app, $petition, $return_to_url, $return_to_seperator, $error_return_url, $error_to_seperator) = @_;

    # check for errors.
    my @errors;
    
    if ($app->param('data1') !~ /.+/) {
        push @errors, 'data1';
    }
    if ($app->param('data2') !~ /.+/) {
        push @errors, 'data2';
    }
    # email is data3
    if (!is_valid_email($app->param('data3'))) {
        push @errors, 'data3';
    }
    if ($app->param('data4') !~ /.+/) {
        push @errors, 'data4';
    }

    if (scalar @errors) {
        $app->redirect($error_return_url .
                       $error_to_seperator .
                       (join ',', @errors));
        return;
    }

    # attempt to locate the submission, in the case of updating it.
    my $updating = 1;
    my $submission = Petition::Submission->load({
        petition_id => $petition->id,
        data3       => $app->param('data3'),
    });

    if (!$submission) {
        $updating = 0;
        $submission = Petition::Submission->new;
    }

    # set the new/refreshed data
    $submission->petition_id($petition->id);
    $submission->data1($app->param('data1'));
    $submission->data2($app->param('data2'));
    $submission->data3($app->param('data3'));
    $submission->data4($app->param('data4'));
    $submission->data5($app->param('data5'));
    $submission->data6($app->param('data6'));
    $submission->data7($app->param('data7'));
    $submission->data8($app->param('data8'));
    $submission->data9($app->param('data9'));
    $submission->data10($app->param('data10'));
    $submission->save();

    if (!$updating) {
        write_submission_count_json($petition->id);
    }

    my $subject = $petition->email_subject || 'Petition Signed';
    my $body = $petition->email_text;

    # send an email to the submitter
    require MT::Mail;
    if (!MT::Mail->send({To => $app->param('data3'), Subject => $subject}, $body)) {
        # log this in the activity log i guess? 
    }

    # success
    my $redirect_query_params = 'success=1';
    if ($updating) {
        $redirect_query_params .= '&updated=1';
    }
    
    # successful redirect
    $app->redirect($return_to_url . $return_to_seperator . $redirect_query_params);
    
}

sub validate_captcha {
    my ($app, $petition) = @_;
    my $blog_id = $petition->blog_id;

    my $plugin = MT->component('Petition')->init;

    my $config = $plugin->get_config_hash("blog:$blog_id");
    my $privatekey = $config->{recaptcha_privatekey};
 
    my $challenge = $app->param('recaptcha_challenge_field');
    my $response = $app->param('recaptcha_response_field');

    my $ua = $app->new_ua({ timeout => 15, max_size => undef });

    return 0 unless $ua;

    require HTTP::Request;
    my $req = HTTP::Request->new(POST => 'http://api-verify.recaptcha.net/verify');
    $req->content_type("application/x-www-form-urlencoded");
    
    require MT::Util;

    my $content = 'privatekey=' . MT::Util::encode_url($privatekey);
    $content .= '&remoteip=' . MT::Util::encode_url($app->remote_ip);
    $content .= '&challenge=' . MT::Util::encode_url($challenge);
    $content .= '&response=' . MT::Util::encode_url($response);

    $req->content($content);

    my $res = $ua->request($req);
    my $c = $res->content;
    if (substr($res->code, 0, 1) eq '2') {
        return 1 if $c =~ /^true\n/;
    }
    0;
}

sub sanitize_return {
    my ($app, $return_to) = @_;
    my $base = $app->base;
    my @bits = split /(\r|\n)/, $return_to;
    $return_to = $bits[0];
    $return_to =~ s/^\s+//;
    $return_to =~ s/\s+$//;

    if ($return_to !~ /^https?:\/\//) {
        return $base . $return_to;
    }
    return $return_to;
}

sub write_submission_count_json {
    my $petition_id = shift;
    require File::Basename;
    require File::Spec;
    use Data::Dumper;

    if ($petition_id =~ /[0-9]+/) {
        my %submission_counts;

        my $iter = Petition::Submission->count_group_by(undef, 
                                 { group => ['petition_id'] });
        while (my ($cnt, $petid) = $iter->()) {
            $submission_counts{$petid} = $cnt;
        }
        my $submissions = $submission_counts{$petition_id};

        my $dirname = File::Spec->rel2abs(
            File::Spec->join(
                File::Basename->dirname(__FILE__), 'plugins/Petition/data/'));
        my $file = File::Spec->join($dirname, "${petition_id}.json");

        open(FILE, ">", $file) or die "Can't open $file";
        flock(FILE, LOCK_EX);
        print FILE "{'submissions': $submissions}";
        flock(FILE, LOCK_UN);
        close FILE;
    }
}




1;
