#!/usr/bin/perl
# a simple reserarch archive helper to set variable in a headfile

###
# Boiler plate
###
use strict;
use warnings;
my $can_dump = eval {
    # this little snippit checks if the cool data structure dumping code is available.
    require Data::Dump;
    Data::Dump->import(qw(dump));
    1;
};
# root of radish pipeline folders
use Env qw(RADISH_PERL_LIB RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); 
my $ERROR_EXIT = 1;
my $GOOD_EXIT  = 0;

if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
if (! defined($RADISH_RECON_DIR) && ! defined ($WORKSTATION_HOME)) {
    print STDERR "Environment variable RADISH_RECON_DIR must be set. Are you user omega?\n";
    print STDERR "   CIVM HINT setenv RADISH_RECON_DIR /recon_home/script/dir_radish\n";
    print STDERR "Bye.\n";
    exit $ERROR_EXIT;
}
if (! defined($RECON_HOSTNAME) && ! defined($WORKSTATION_HOSTNAME)) {
    print STDERR "Environment variable RECON_HOSTNAME or WORKSTATION_HOSTNAME must be set.";
    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);
#
# for the auto_opt
#
use Getopt::Long ;
Getopt::Long::Configure ("bundling", "ignorecase_always");
#
#####

###
# fairly standard includes
###
use English;
use File::Basename;
use File::Glob qw(:globally :nocase);

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
use pipeline_utilities;
use civm_simple_util qw(activity_log load_file_to_array get_engine_constants_path find_file_by_pattern printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_val $debug_locator);
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
    #    my $v_hash={"global_1=s"=>\$global_1, "global_2=s"=>\$global_2, "bool_input"=>\$option_hash{"bool_readback"}, "local_int=i"=> \$local_int, "floatnumber=f"=>\$local_float}; # example of the possibilities
    my $v_hash={};
    # for good error checking the hash key can take they expected value type.
    # values types can be s i o f   O is extended integer...?
    # values can boolean or take a value, when taking a value it can be optional using : instead of =;
    #             $arg_hash{extra_runno_suffix}=$extra_runno_suffix;
    my $href=auto_opt($v_hash);

    
    my $ec=load_engine_deps();#$engine
    my $HfResult_path="";
    my $hfmode='new';
    my @fnames=find_file_by_pattern($ec->get_value('engine_recongui_paramfile_directory'),'^arp_.*$');
    if (scalar(@fnames)>0){
	$HfResult_path=$fnames[0];#$ec->get_value('engine_recongui_paramfile_directory').'/'.
	$hfmode='rc';
    }
    # .'/arp_'.$HfResult->get_value("archivesource_item")  ,# paramfilepath
    
    ###
    # define the required entries, and set a rough help for them
    ###
    my $lookup={};
    $lookup->{"archivedestination_unique_item_name"}=
	"REQ: Runnumber to be stored in DB ex (B000001)";
    $lookup->{"U_specid"}=
	"REQ: specimen code for DB ex 100101-1:0";
    $lookup->{"archivedestination_project_directory_name"}=
	"REQ: Project code ex (00.blabla.01)";
    $lookup->{"U_civmid"}=
	"OPT: civmuser (initials or short name), ex (you)";
    #$lookup->{"archivesource_item"}=
    #"local folder name, ex myspecialdata, can leave blank and will use ";
    #$lookup->{"archivesource_directory"}=
    #"remote directory, generally the spacename ex ".$ec->get_value('engine_work_directory');
    $lookup->{"U_optional"}=
	"OPT: an 80 character string telling especially important info";
    $lookup->{"U_root_runno"}=
	"OPT: source data if there is any, otherwise leave blank ex (B000001)";
    my @k=keys(%$lookup);# get the list of keys, Before we add U_data_folder, because we want to prompt for that first, and outside the rest.
    $lookup->{"U_data_folder"}=
	"REQ: the local data folder ex. (".$ec->get_value('engine_work_directory').'/'."myspecialdata)";
    
    $HfResult = new Headfile ($hfmode, $HfResult_path);
    if($hfmode eq 'rc'){ # rc is re-create hf, nf is new file. maybe nf is better type?
	$HfResult->read_headfile if ($HfResult->check());
    }
    # Prompt for data folder first, then get all the rest.
    $HfResult->set_value("U_data_folder","__NULL____");
    while( ! -d $HfResult->get_value("U_data_folder") ){
	print("Didnt find data folder, please enter\n");
	$HfResult->set_value("U_data_folder",lpprompt($lookup->{"U_data_folder"}));
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
	my $lv=$HfResult->get_value($_);
	if ($lv =~  /^(NO_KEY|UNDEFINED_VALUE|EMPTY_VALUE)$/ ){
	    $lv=''; # set blank for no existing val
	} else {
	    $lv=" current ($lv)";
	}
	my $v=lpprompt($lookup->{$_}.$lv);
	if ($v ne "") {
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
	exit $GOOD_EXIT;
    } else {
	printd(5,join("\n",@errors));
	exit $ERROR_EXIT
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
    
sub auto_opt  { 
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
    if ( $can_dump && $debug_val>=45) {
	printd(45,"Show the arg_hash before sent off to GetOptions\n");
	Data::Dump::dump($o);
    }
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
