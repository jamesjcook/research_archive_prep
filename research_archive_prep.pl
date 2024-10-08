#!/usr/bin/env perl
# To keep up with ever improving boiler plate ideas, this exists to capture them
# Boilerplate code is rarely updated, but often it's a good idea.
# So this'll exist as a record of the "current standard" maybe, riddled with me
# explaining things to ... me.
#
# Special she-bang finds default perl. This should be correct most the time from here forward.
use strict;
use warnings FATAL => qw(uninitialized);
# carp and friends, backtrace yn, fatal yn
use Carp qw(cluck confess carp croak);
our $DEF_WARN=$SIG{__WARN__};
our $DEF_DIE=$SIG{__DIE__};
# Seems like it'd be great to have this signal handler dependent on debug_val.
# hard to wire that into a general concept.
# compile time issues, but probably fine at runtime.
#$SIG{__WARN__} = sub { cluck "Undef value: @_" if $_[0] =~ /undefined|uninitialized/;&{$DEF_WARN}(@_) };
$SIG{__WARN__} = sub {
    cluck "Undef value: @_" if $_[0] =~ /undefined|uninitialized/;
    #if(defined $DEF_WARN) { &{$DEF_WARN}(@_)}
    if(defined $DEF_WARN) {
        &{$DEF_WARN}(@_);
    } else { warn(@_); }
  };

#### VAR CHECK
# Note, vars will have to be hardcoded becuased this is a check for env.
# That means, ONLY variables which will certainly exist should be here.
# BOILER PLATE
BEGIN {
    # we could import radish_perl_lib direct to an array, however that complicates the if def checking.
    my @env_vars=qw(RADISH_PERL_LIB BIGGUS_DISKUS WORKSTATION_DATA WORKSTATION_HOME);
    my @errors;
    use Env @env_vars;
    foreach (@env_vars ) {
        push(@errors,"ENV missing: $_") if (! defined(eval("\$$_")) );
    }
    die "Setup incomplete:\n\t".join("\n\t",@errors)."\n  quitting.\n" if @errors;
}
use lib split(':',$RADISH_PERL_LIB);

use Cwd qw(abs_path);
use File::Basename;
BEGIN {
    # In rare conditisons __FILE__ and abs_path fail.
    # These seem to be permission related.
    # Specifically, it appears if we have permission to the file, but NOT to the link this can occur.
    my $fp=abs_path(__FILE__);
    if(! defined $fp ){ die "error getting code path";}
    if($fp eq "" ){ die "error getting code path, got blank";}
    my $dx=dirname($fp);
}
#use lib dirname(abs_path($0));
use lib dirname(abs_path(__FILE__));

# my absolute fav civm_simple_util components.
use civm_simple_util qw(activity_log printd $debug_val);
# On the fence about including pipe utils every time
use pipeline_utilities;
# pipeline_utilities uses GOODEXIT and BADEXIT, but it doesnt choose for you which you want.
$GOODEXIT = 0;
$BADEXIT  = 1;
# END BOILER PLATE

# a simple reserarch archive helper to set variable in a headfile

###
# pipe vars
###

my $PIPELINE_VERSION = "2018/03/09";
my $PIPELINE_NAME = "r_a_prep";
my $PIPELINE_DESC = "CIVM research archive preparator";

###
# civm includes
###
require Headfile;
#require hoaoa;
#import hoaoa qw(aoa_hash_to_headfile);
use hoaoa qw(aoa_hash_to_headfile);
#require shared;
use civm_simple_util qw( load_file_to_array find_file_by_pattern trim whoami whowasi debugloc sleep_with_countdown $debug_locator);
use vars qw($HfResult);
#
activity_log();
$debug_val=10;



###
# Run the main
###
main();
exit;



sub main  {

    my $ec=load_engine_deps();#$engine
    ###
    # define the required entries, and set a rough help for them
    ###
    my $lookup={};
    ${$lookup->{"archivedestination_unique_item_name=s"}}=
        "REQ: Runnumber to be stored in DB ex (B000001)";
    ${$lookup->{"U_specid=s"}}=
        "REQ: specimen code for DB ex 100101-1:0";
    ${$lookup->{"archivedestination_project_directory_name=s"}}=
        "REQ: Project code ex (00.blabla.01)";
    ${$lookup->{"U_civmid:s"}}=
        "OPT: civmuser (initials or short name), ex (you)";
    #$lookup->{"archivesource_item"}=
    #"local folder name, ex myspecialdata, can leave blank and will use ";
    #$lookup->{"archivesource_directory"}=
    #"remote directory, generally the spacename ex ".$ec->get_value('engine_work_directory');
    ${$lookup->{"U_optional:s"}}=
        "OPT: an 80 character string telling especially important info";
    ${$lookup->{"U_root_runno:s"}}=
        "OPT: source data if there is any, otherwise leave blank ex (B000001)";
    # we'll maintain ta list of keys outside the hash so we can filter for non-args of importance.
    my @k=keys(%$lookup);# get the list of keys, Before we add U_data_folder, because we want to prompt for that first, and outside the rest.
    ${$lookup->{"U_data_folder=s"}}=
        "REQ: the local data folder ex. (".$ec->get_value('engine_work_directory').'/'."myspecialdata)";
    push(@k, "U_data_folder");

    # for good error checking the hash key can take they expected value type.
    # values types can be s i o f   O is extended integer...?
    # values can boolean or take a value, when taking a value it can be optional using : instead of =;
    #             $arg_hash{extra_runno_suffix}=$extra_runno_suffix;
    ${$lookup->{"auto_opt_deref_scalar"}}=1;
    $lookup=auto_opt($lookup);

    # cleanu p keys because of the option processing suffixes
    # only =s supported just now.
    foreach(@k){
        $_ =~ s/[:=]s$//x;
    }
    #Data::Dump::dump($lookup); die "testing";

    my $HfResult_path="";
    my $hfmode='new';

    # this is cache of the previous run, needt o handle better
    # is this okay beacuse fnames will be a time sorted list? or is this just a distracty pos?
    my @fnames=find_file_by_pattern($ec->get_value('engine_recongui_paramfile_directory'),'^arp_.*$');
    if (scalar(@fnames)>0){
        $HfResult_path=$fnames[0];#$ec->get_value('engine_recongui_paramfile_directory').'/'.
        $hfmode='rc';
    }
    # .'/arp_'.$HfResult->get_value("archivesource_item")  ,# paramfilepath


    $HfResult = new Headfile ($hfmode, $HfResult_path);
    if($hfmode eq 'rc'){ # rc is re-create hf, nf is new file. maybe nf is better type?
        $HfResult->read_headfile if ($HfResult->check());
    }

    # IF not given as a command line arg, prompt.
    if( $lookup->{"U_data_folder"} =~ m/^REQ:/xi ) {
        # Prompt for data folder first, then get all the rest.
        $HfResult->set_value("U_data_folder","__NULL____");
        while( ! -d $HfResult->get_value("U_data_folder") ){
            print("Didnt find data folder, please enter\n");
            $HfResult->set_value("U_data_folder",lpprompt($lookup->{"U_data_folder"}));
        }
    }

    # $HfResult->set_value('U_civmid',$HfResult->get_value_like('U_civmid'));
    # Insert archivereserach required items at last second.
    $HfResult->set_value('U_db_insert_type'                         , "research");
    $HfResult->set_value('archivesource_item_form'                  , "directory-set");
    $HfResult->set_value('archivesource_computer'                   , $ec->get_value('engine') );
    #engine_work_directory=/panoramaspace
    # $HfResult->set_value('archivesource_item'                       , $last_dir);
    # $HfResult->set_value('archivesource_directory'                  , $path );
    # $HfResult->set_value('archivedestination_unique_item_name'      , $HfResult->get_value('result_runno'));
    $HfResult->set_value('archivesource_headfile_creator'           , "$PIPELINE_NAME $PIPELINE_VERSION");
    # $HfResult->set_value('archivedestination_project_directory_name', $HfResult->get_value('subproject-source'));
    # # optional but good fields
    # $HfResult->set_value('U_optional'  ,'co_reg transforms for diffusion distortion');
    # $HfResult->set_value('U_root_runno',$first_runno);

    ###
    # Prompt for items
    ###
    # prefetch scanner for better last setting handler.
    # "U_scanner"
    #Data::Dump::dump(@k);
    foreach(@k){
        # last value
        my $lv=$HfResult->get_value($_);
        if ($lv =~  /^(NO_KEY|UNDEFINED_VALUE|EMPTY_VALUE)$/ ){
            $lv=''; # set blank for no existing val
        } else {
            $lv=" current ($lv)";
        }

        my $v=$lookup->{$_};

        # for some reason lookup value not set?
        if( ! defined $v || $v =~ m/^(REQ|OPT):/xi ) {
            printd(45,"$_ not defined in lookup\n") if ! defined $v;
            $v=lpprompt($lookup->{$_}.$lv);
        }
        require Scalar::Util;
        Scalar::Util->import(qw(looks_like_number));
        if ($v ne "" && ! looks_like_number($v) ) {
            $HfResult->set_value($_,trim($v));
        }
    }
    ####
    # auto-figure some items
    ###
    #$HfResult->set_value("archivesource_item",depath($HfResult->get_value("U_data_folder")));
    my ($p,$n,$e)=fileparts($HfResult->get_value("U_data_folder"),3);
    $HfResult->set_value("archivesource_item",$n);
    # could use file path too, but they should match.
    #$HfResult->set_value("archivesource_directory",$ec->get_value('engine_work_directory'));
    # Found with lucy they wont match if users want nested directories in the work folder.
    $HfResult->set_value("archivesource_directory",$p);

    $HfResult->set_value('U_date'      , $HfResult->now_date_db());
    #log_info  ("Pipeline successful");
    #close_log ($HfResult);                      # writes log to headfile, then closes
    # fix HfResult_path
    my @errors=();
    for my $op (
        $HfResult->get_value("U_data_folder").'/'
        .$HfResult->get_value("archivedestination_unique_item_name").".headfile"  , # archivepath
        $ec->get_value('engine_recongui_paramfile_directory').'/'
        .'arp_'.$HfResult->get_value("archivedestination_unique_item_name").".headfile"  # paramfilepath
        ) {
        my $hf= new Headfile ('new', $op);
        if ($hf->check()) {
            $hf->copy_in($HfResult);
            $hf->write_headfile($op);# write headfile
        } else {
            push(@errors,"Write problem for hf!\n\tHas this data already been prepared?\n\tDid not write: $op\n");
        }
    }

    if ( !scalar(@errors) ) {
        exit $GOODEXIT;
    } else {
        printd(5,join("\n",@errors));
        exit $BADEXIT;
    }
}

sub lpprompt {
    my($prmpt)=@_;
    my $entry="";
    #while ($entry eq "" ){
        print($prmpt."\n\t> ");
        $entry= <STDIN>;
        chomp $entry;
    #}
    return $entry;
}

sub primitive_auto_opt  {
    # demonstrating how to put the getoption code in a function.
    # this isnt necessary, its just helpful so it can be moved around easily in the code.
    # this could be the mechanism behind common options, where our main function passed
    # in any which were specific to the process we're doing.
    my ($in,@yarrrgh_I_takesaHashref_and_junksbehere)=@_;
    # @yarrrgh_I_takesaHashref_and_junksbehere could be a way to have ARGV get into the option function.

    my $o={}; # make a hash ref to be returned.
    # add some values in the hash ref only,
    #$o->{"somestring=s"}='defaultstring';
    #$o->{"someint=i"}=0;

    $o={%{$o},%{$in}}; # add the input hash to any we want to hard code into auto_opt.
    disp(["Show the arg_hash before sent off to GetOptions\n",$o]);

    # Quick patch to dump argument options right into getoptions
    # values types can be s i o f   O is extended integer...?
    # values can be boolean or take a value, when taking a value it can be optional using : instead of =;
    #             $arg_hash{extra_runno_suffix}=$extra_runno_suffix;
    if ( !GetOptions( %$o ) ) {
        warn "\n# \n# \n# WARNING: Problem with command line options.\n# \n# \n# ";
        # this is a good place to use the error_out function.
    }
    return( $o);
}

1;
