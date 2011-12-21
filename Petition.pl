package MT::Plugin::Petition;

use strict;
use MT;
use base qw( MT::Plugin );
our $VERSION = '0.1';

use MT::Util;

my $plugin = MT::Plugin::Petition->new({
    id          => 'Petition',
    key         => 'petition',
    name        => 'Petition',
    description => "Create petitions",
    version     => $VERSION,
    schema_version => 1.0011,
    author_name => "Six Apart",
    author_link => "http://www.sixapart.com/",
    plugin_link => "http://plugins.movabletype.org/",
    l10n_class => 'Petition::L10N',
                                       });

MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;

    $plugin->registry({
        object_types => {
            'petitionpetition' => 'Petition::Petition',
            'petitionquestion' => 'Petition::Question',
            'petitionanswer' => 'Petition::Answer',
            'petitionsubmission' => 'Petition::Submission',
        },
        blog_config_template => <<TMPL,
 <dl>
 <dt>reCaptcha public key</dt>
 <dd><input name="recaptcha_publickey" size="40" value="<mt:var name="recaptcha_publickey">" /></dd>
 <dt>reCaptcha private key</dt>
 <dd><input name="recaptcha_privatekey" size="40" value="<mt:var name="recaptcha_privatekey">" /></dd>
 </dl>
TMPL
        settings => new MT::PluginSettings([
           ['recaptcha_publickey', { Scope   => 'blog' }],
           ['recaptcha_privatekey', { Scope   => 'blog' }],
        ]),
        tags => {
            function => {
                'PetitionReCaptcha' => \&_hdlr_Petition_ReCaptcha,
                'PetitionIDHidden' => \&_hdlr_Petition_ID_Hidden,
                'PetitionDescription' => \&_hdlr_Petition_Description,
                'PetitionTitle' => \&_hdlr_Petition_Title,
                'PetitionQuestions' => \&_hdlr_Petition_Questions,
                'PetitionActionURL' => \&_hdlr_Petition_Action_URL,
                'PetitionThankYou' => \&_hdlr_Petition_Thank_You,
                'PetitionCampaignID' => \&_hdlr_Petition_Campaign_ID,
            },
        },
        applications => {
            cms => {
                methods => {
                    edit_petition => '$Petition::Petition::CMS::edit_petition',
                    save_petition => '$Petition::Petition::CMS::save_petition',
                    list_petitions => '$Petition::Petition::CMS::list_petitions',
                    export_petition_results => '$Petition::Petition::CMS::export_petition_results',
                },
                menus => {
                    'create:Petition' => {
                        label => 'Petition',
                        mode => 'edit_petition',
                        order => 302,
                        args => { _type => "blog" },
                        permission => 'publish_post',
                        view => "blog",
                    },
                    'manage:petition' => {
                        label => 'Petitions',
                        mode => 'list_petitions',
                        order => 10001,
                        args => { _type => "blog" },
                        permission => 'publish_post',
                        view => "blog",
                    },
                },
            },
            community => {
                methods => {
                    process_petition => '$Petition::Petition::process_submission',
                    process_widget_petition => '$Petition::Petition::process_widget_submission',
                }
            }
        },
        default_templates => {
	        base_path   => 'tmpl',
                    'global:system' => {
                        petition_confirmation => {
                            label => 'Petition Confirmation',
                        },
                    },
        },
    });
}

sub _hdlr_PollInclude {
   my ($ctx, $args, $cond) = @_;
   my $path = $ctx->_hdlr_static_path();

   my $out = "";
   $out .= <<END;
    <script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/utilities/utilities.js"></script>
        <script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/cookie/cookie-beta.js"></script>
        <link rel="stylesheet" href="${path}plugins/Petition/css/main.css" type="text/css" media="screen" />
        <script type="text/javascript" src="${path}plugins/Petition/js/app.js"></script>

END
   return $out;
}

sub _hdlr_Petition_ReCaptcha {
    my ($ctx, $args, $cond) = @_;

    my $blog_id = $ctx->stash('blog_id');

#    require MT::Plugin::Petition;

    my $plugin = MT->component('Petition')->init;

    my $config = $plugin->get_config_hash("blog:$blog_id");
    my $publickey = $config->{recaptcha_publickey};
    my $privatekey = $config->{recaptcha_privatekey};


    return q() unless $publickey && $privatekey;

    return <<FORM_FIELD;
<div id="recaptcha_script" style="display:block">
<script type="text/javascript"
   src="http://api.recaptcha.net/challenge?k=$publickey">
</script>

<noscript>
   <iframe src="http://api.recaptcha.net/noscript?k=$publickey"
       height="300" width="500" frameborder="0"></iframe><br>
   <textarea name="recaptcha_challenge_field" rows="3" cols="40">
   </textarea>
   <input type="hidden" name="recaptcha_response_field"
       value="manual_challenge">
</noscript>
</div>
FORM_FIELD
}

sub _hdlr_Petition_Campaign_ID {
    my ($ctx, $args, $cond) = @_;
    
    my $blog_id = $ctx->stash('blog_id') || 0;

    my $val = MT->model('fdvalue')->load({
        object_type => 'blog',
        object_id => $blog_id,
        key => 'petition_id',
    });

    return $val ? $val->value : '';
}

sub _hdlr_Petition_Description {
    my ($ctx, $args, $cond) = @_;

    require Petition::Petition;

    my $blog_id = $ctx->stash('blog_id') || 0;
    my $petition;
    my $petition_id;

    if ($petition_id = $args->{id}) {
        if ($petition = $ctx->stash('petition_' . $args->{id})) {
            return $petition->description;
        }
    } 
    elsif ($petition = $ctx->stash('petition')) {
        return $petition->description;
    }

    # have to go get it.
    if ($petition_id) {
        $petition = Petition::Petition->load( { id => $args->{id} });
        $ctx->stash('petition_' . $petition_id, $petition);
    }
    else {
        $petition = Petition::Petition->load({ featured => 1, blog_id => $blog_id });
        $ctx->stash('petition', $petition);
    }
    return $petition->description;
}

sub _hdlr_Petition_Title {
    my ($ctx, $args, $cond) = @_;

    require Petition::Petition;

    my $blog_id = $ctx->stash('blog_id') || 0;

    my $petition;
    my $petition_id;

    if ($petition_id = $args->{id}) {
        if ($petition = $ctx->stash('petition_' . $args->{id})) {
            return $petition->title;
        }
    } 
    elsif ($petition = $ctx->stash('petition')) {
        return $petition->title;
    }

    # have to go get it.
    if ($petition_id) {
        $petition = Petition::Petition->load( { id => $args->{id} });
        $ctx->stash('petition_' . $petition_id, $petition);
    }
    else {
        $petition = Petition::Petition->load({ featured => 1, blog_id => $blog_id  });
        $ctx->stash('petition', $petition);
    }
    return $petition->title;
}


sub _hdlr_Petition_Thank_You {
    my ($ctx, $args, $cond) = @_;

    require Petition::Petition;
    require MT::Util;

    my $blog_id = $ctx->stash('blog_id') || 0;

    my $petition;
    my $petition_id;

    if ($petition_id = $args->{id}) {
        if ($petition = $ctx->stash('petition_' . $args->{id})) {
            return MT::Util::html_text_transform($petition->thank_you);
        }
    } 
    elsif ($petition = $ctx->stash('petition')) {
        return MT::Util::html_text_transform($petition->thank_you);
    }

    # have to go get it.
    if ($petition_id) {
        $petition = Petition::Petition->load( { id => $args->{id} });
        $ctx->stash('petition_' . $petition_id, $petition);
    }
    else {
        $petition = Petition::Petition->load({ featured => 1, blog_id => $blog_id  });
        $ctx->stash('petition', $petition);
    }
    return MT::Util::html_text_transform($petition->thank_you);
}


sub _hdlr_Petition_ID_Hidden {
    my ($ctx, $args, $cond) = @_;

    require Petition::Petition;

    my $blog_id = $ctx->stash('blog_id') || 0;

    my $petition;
    my $petition_id;

    if ($petition_id = $args->{id}) {
        if ($petition = $ctx->stash('petition_' . $args->{id})) {
            return '<input type="hidden" name="__mode" value="process_petition" /><input type="hidden" name="petition_id" id="petition_id" value="' . $petition_id . '" />';
        }
    } 
    elsif ($petition = $ctx->stash('petition')) {
        return '<input type="hidden" name="__mode" value="process_petition" /><input type="hidden" id="petition_id" name="petition_id" value="' . $petition->id . '" />';
    }

    # have to go get it.
    if ($petition_id) {
        $petition = Petition::Petition->load( { id => $args->{id} });
        $ctx->stash('petition_' . $petition_id, $petition);
    }
    else {
        $petition = Petition::Petition->load({ featured => 1, blog_id => $blog_id  });
        $ctx->stash('petition', $petition);
    }
    return '<input type="hidden" name="__mode" value="process_petition" /><input type="hidden" id="petition_id" name="petition_id" value="' . $petition_id . '" />';
}


use Petition::Question;

# build a petition
sub _hdlr_Petition_Questions {
   my ($ctx, $args, $cond) = @_;

   require Petition::Petition;
   require Petition::Answer;

   my @out;

   my $blog_id = $ctx->stash('blog_id');

   my $petition;

   if (defined($args->{id})) {
      $petition = Petition::Petition->load( { id => $args->{id} });
   } else {
      # Find the current selected poll
      $petition = Petition::Petition->load( {featured => 1, blog_id => $blog_id } );
   }

   return '' if (!$petition);

   my @questions = Petition::Question->load(
                            {petition_id => $petition->id()},
                            {sort => 'display_order', direction => 'ascend'}
                   );

   foreach my $q (@questions) {
       if ($q->has_answers) {
           my @answers = Petition::Answer->load(
               { question_id => $q->id()},
               { sort => 'display_order', direction => 'ascend'}
               );
           # html should depend on type, i.e. select, or checkboxes, radios
           
           my $type = $q->type;
           my $questext = $q->question;
           my $quesdo = $q->display_order;
           my $qid = "data$quesdo";

           if ($type == Petition::Question::SELECT) {
               my $fieldcontent =  "<select class=\"select\" name=\"$qid\" id=\"$qid\">";
               for my $a (@answers) {
                   my $anstext = $a->text;
                   my $ansdo = $a->display_order;
                   $fieldcontent .= "<option value=\"$anstext\">$anstext</option>";
               }
               $fieldcontent .= "</select>";

               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
           elsif ($type == Petition::Question::CHECKBOXES) {
               my $fieldcontent = "<ul class=\"petition-question-checkboxes\">";
               for my $a (@answers) {
                   my $ansdo = $a->display_order;
                   my $anstext = $a->text;
                   $fieldcontent .="<li><input type=\"checkbox\" class=\"input-checkbox\" name=\"$qid\" id=\"${qid}_$ansdo\" value=\"$anstext\" /> <label for=\"${qid}_$ansdo\">$anstext</label></li>";
               }
               $fieldcontent .= "</ul>";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
           else {
               my $fieldcontent = "<ul class=\"petition-question-checkboxes\">";
               for my $a (@answers) {
                   my $ansdo = $a->display_order;
                   my $anstext = $a->text;
                   $fieldcontent .="<li><input type=\"radio\" class=\"input-radio\" name=\"$qid\" id=\"${qid}_$ansdo\" value=\"$anstext\" /> <label for=\"${qid}_$ansdo\">$anstext</label></li>";
               }
               $fieldcontent .= "</ul>";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
       }
       else {
           my $type = $q->type;
           my $questext = $q->question;
           my $quesdo = $q->display_order;
           my $qid = "data$quesdo";

           my $validation = 'input-text';

           if ($q->validation) {
               $validation .= " " . $q->validation;
           }
           if ($type == Petition::Question::SHORTTEXT) {
               $validation .= " short";
           }

           if ($q->required && length($validation)) {
               $questext .= " *";               
               $validation .= " required";
           }
           elsif ($q->required) {
               $questext .= " *";
               $validation .= "required";
           }

           if ($type == Petition::Question::CHECKBOX) {
               my $fieldcontent = "<input type=\"checkbox\" name=\"$qid\" id=\"$qid\" value=\"yes\" />";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
           elsif ($type == Petition::Question::SHORTTEXT) {
               my $fieldcontent = "<input type=\"text\" class=\"$validation\" name=\"$qid\" id=\"$qid\" value=\"\" />";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
           elsif ($type == Petition::Question::LONGTEXT) {

               my $fieldcontent = "<textarea name=\"$qid\" class=\"$validation\" id=\"$qid\"></textarea>";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
           else {
               my $fieldcontent = "<input type=\"text\" class=\"$validation\" name=\"$qid\" id=\"$qid\" value=\"\" />";
               push @out, mt_normal_setting($qid, $questext, $fieldcontent, $q->required, $q->slug);
           }
       }
   }

   return join '', @out;
}


sub _hdlr_Petition_Details {
   my ($ctx, $args, $cond) = @_;
   my $petition;
   my $blog_id = $ctx->stash('blog_id');

   my $petition_id;
    if ($petition_id = $args->{id}) {
        if ($petition = $ctx->stash('petition_' . $args->{id})) {
            return $petition->description;
        }
    } 
    elsif ($petition = $ctx->stash('petition')) {
        return $petition->description;
    }

    # have to go get it.
    if ($petition_id) {
        $petition = Petition::Petition->load( { id => $args->{id} });
        $ctx->stash('petition_' . $petition_id, $petition);
    }
    else {
        $petition = Petition::Petition->load({ featured => 1, blog_id => $blog_id  });
        $ctx->stash('petition', $petition);
    }

   return '' if !$petition;
   return '<input type="hidden" name="petition_id" value="' . $petition->id() . '" />';
}

# outputs the url to the CGI script for use in form action
sub _hdlr_Petition_Action_URL {
    my ($ctx, $args, $cond) = @_;
    return $ctx->_hdlr_cgi_path($ctx) . $ctx->{config}->CommunityScript;
}

sub mt_normal_setting {
    my ($id, $label, $fieldcontent, $required, $slug) = @_;
    my $slugid;
    if (length($slug)) {
        $slugid = ' id="' . $slug . '-container"';
    }
    return <<TMPL;
<div id="$id-field" class="field pkg">
   <div class="field-inner"$slugid>
       <div class="field-header">
           <label id="$id-label" for="$id">$label</label>
       </div>
       <div class="field-content">
           $fieldcontent
       </div>
   </div>
</div>
TMPL
}
