use Carp;
use Text::Format;
use ::Assign qw(:all);
$text_wrap = new Text::Format {
	columns 		=> 75,
	firstIndent 	=> 0,
	bodyIndent		=> 0,
	tabstop			=> 4,
};

sub show_versions {
 	"All versions: ". join " ", @{$this_track->versions}, $/
		if @{$this_track->versions};
}

sub show_effects {
	my @lines;
 	map { 
 		my $op_id = $_;
		my @params;
 		 my $i = $effect_i{ $cops{ $op_id }->{type} };
 		 push @lines, $op_id. ": " . $effects[ $i ]->{name}.  "\n";
 		 my @pnames = @{$effects[ $i ]->{params}};
			map{ push @lines,
			 	"    " . $pnames[$_]->{name} . ": ".  $copp{$op_id}->[$_] . "\n";
		 	} (0..scalar @pnames - 1);
			#push @lines, join("; ", @params) . "\n";
 
 	 } @{ $this_track->ops };
	join "", @lines;
 	
}
sub show_modifiers {
	join "", "Modifiers: ",$this_track->modifiers, $/
		if $this_track->modifiers;
}
sub show_region {
	my @lines;
	push @lines, "Start delay: ",
		$this_track->playat, $/ if $this_track->playat;
	push @lines, "Region start: ", $this_track->region_start, $/
		if $this_track->region_start;
	push @lines, "Region end: ", $this_track->region_end, $/
		if $this_track->region_end;
	join "", @lines;
}

sub show_status {
	my @fields;
	push @fields, $tracker->rw eq 'REC' 
					? "live input allowed" 
					: "live input disabled";
	push @fields, "record" if ::really_recording();
	push @fields, "playback" if grep { $_->rec_status eq 'MON' } 
		map{ $tn{$_} } $tracker->tracks, q(Mixdown);
	push @fields, "mixdown" 
		if $tn{Mixdown}->rec_status eq 'REC' and $mix_down->status;
	push @fields, "doodle" if $preview eq 'doodle';
	push @fields, "preview" if $preview eq 'preview';
	push @fields, "master" if $mastering_mode;
	"[ ". join(", ", @fields) . " ]\n";
}
	
sub poll_jack {
	package ::;
	$event_id{Event_poll_jack} = Event->timer(
	    desc   => 'poll_jack',               # description;
	    prio   => 5,                         # low priority;
		interval => 5,
	    cb     =>   \&jack_update, # callback;
	);
}

sub install_handlers {

	# we are using the Event module's handlers and event loop
	
	package ::;

	# setup Term::Readline::GNU
	$term = new Term::ReadLine("Ecasound/Nama");
	$attribs = $term->Attribs;
	$attribs->{attempted_completion_function} = \&complete;

	# store output buffer in a scalar (for print)
	my $outstream = $attribs->{'outstream'};

	# install STDIN handler
	$event_id{stdin} = Event->io(
		desc   => 'STDIN handler',           # description;
		fd     => \*STDIN,                   # handle;
		poll   => 'r',	                   # watch for incoming chars
		cb     => sub{ 

					&{$attribs->{'callback_read_char'}}();
					if ( $attribs->{line_buffer} eq " " ){
						if (engine_running()){ stop_transport() }
						else { start_transport() }
						$attribs->{line_buffer} = q();
 						$attribs->{point} 		= 0;
 						$attribs->{end}   		= 0;
						$term->stuff_char(10);
					    &{$attribs->{'callback_read_char'}}();

					}
 				},
		repeat => 1,                         # keep alive after event;
	 );
#  	$event_id{sigint} = Event->signal(
#  		desc   => 'Signal handler',           # description;
#  		signal => $SIG{INT},
#  		cb     => sub{ die "here" }, # callback;
#  	 );

	$event_id{Event_heartbeat} = Event->timer(
		parked => 1, 						# start it later
	    desc   => 'heartbeat',               # description;
	    prio   => 5,                         # low priority;
		interval => 3,
	    cb     => \&heartbeat,               # callback;
	);
	if ( $midi_inputs =~ /on|capture/ ){
		my $command = "aseqdump ";
		$command .= "-p $controller_ports" if $controller_ports;
		open MIDI, "$command |" or die "can't fork $command: $!";
		$event_id{sequencer} = Event->io(
			desc   => 'read ALSA sequencer events',
			fd     => \*MIDI,                    # handle;
			poll   => 'r',	                     # watch for incoming chars
			cb     => \&process_control_inputs, # callback;
			repeat => 1,                         # keep alive after event;
		 );
		$event_id{sequencer_error} = Event->io(
			desc   => 'read ALSA sequencer events',
			fd     => \*MIDI,                    # handle;
			poll   => 'e',	                     # watch for exception
			cb     => sub { die "sequencer pipe read failed" }, # callback;
		 );
	
	}
}
sub loop {
	package ::;
	$term->callback_handler_install($prompt, \&process_line);
	Event::loop();

}
sub wraparound {
	package ::;
	@_ = discard_object(@_);
	my ($diff, $start) = @_;
	#print "diff: $diff, start: $start\n";
	$event_id{Event_wraparound}->cancel()
		if defined $event_id{Event_wraparound};
	$event_id{Event_wraparound} = Event->timer(
	desc   => 'wraparound',               # description;
	after  => $diff,
	cb     => sub{ set_position($start) }, # callback;
   );

}


sub start_heartbeat {$event_id{Event_heartbeat}->start() }

sub stop_heartbeat {$event_id{Event_heartbeat}->stop() }

sub cancel_wraparound {
	$event_id{Event_wraparound}->cancel() if defined $event_id{Event_wraparound}
}


sub placeholder { 
	my $val = shift;
	return $val if $val;
	$use_placeholders ? q(--) : q() 
}

{
my $format_top = <<TOP;
Track Name      Ver. Setting  Status   Source           Send        Vol  Pan 
=============================================================================
TOP

my $format_picture = <<PICTURE;
@>>   @<<<<<<<<< @>    @<<     @<< @|||||||||||||| @||||||||||||||  @>>  @>> 
PICTURE

sub show_tracks {
    no warnings;
	$^A = $format_top;
    my @tracks = @_;
    map {   formline $format_picture, 
            $_->n,
            $_->name,
            placeholder( $_->current_version ),
			(ref $_) =~ /MasteringTrack/ 
					? placeholder() 
					: lc $_->rw,
            $_->rec_status,
            $_->name =~ /Master|Mixdown/ 
					? placeholder() 
					: placeholder($_->source_status),
			placeholder($_->send_status),
			placeholder($copp{$_->vol}->[0]),
			placeholder($copp{$_->pan}->[0]),
            #(join " ", @{$_->versions}),

        } grep{ ! $_-> hide} @tracks;
        
    #write; # using format below
    #$- = 0; # $FORMAT_LINES_LEFT # force header on next output
	
    #1;
    #use warnings;
    #no warnings q(uninitialized);
	my $output = $^A;
	$^A = "";
	#$output .= show_tracks_extra_info();
	$output;
}

}

sub show_tracks_extra_info {

	my $string;
	$string .= $/. "Global version setting: ".  $::tracker->version. $/
		if $::tracker->version;
	$string .=  $/. ::Text::show_status();
	$string .=  $/;	
	$string;
}


format STDOUT_TOP =
Track Name      Ver. Setting  Status   Source           Send        Vol  Pan 
=============================================================================
.
format STDOUT =
@>>   @<<<<<<<<< @>    @<<     @<< @|||||||||||||| @||||||||||||||  @>>  @>> ~~
splice @format_fields, 0, 9
.

sub helpline {
	my $cmd = shift;
	my $text = "Command: $cmd\n";
	$text .=  "Shortcuts: $commands{$cmd}->{short}\n"
			if $commands{$cmd}->{short};	
	$text .=  "Description: $commands{$cmd}->{what}\n";
	$text .=  "Usage: $cmd "; 

	if ( $commands{$cmd}->{parameters} 
			&& $commands{$cmd}->{parameters} ne 'none' ){
		$text .=  $commands{$cmd}->{parameters}
	}
	$text .= "\n";
	$text .=  "Example: ". eval( qq("$commands{$cmd}->{example}") ) . $/  
			if $commands{$cmd}->{example};
	($/, ucfirst $text, $/);
	
}
sub helptopic {
	my $index = shift;
	$index =~ /^(\d+)$/ and $index = $help_topic[$index];
	my @output;
	push @output, "\n-- ", ucfirst $index, " --\n\n";
	push @output, $help_topic{$index}, $/;
	@output;
}

sub help { 
	my $name = shift;
	chomp $name;
	#print "seeking help for argument: $name\n";
	$iam_cmd{$name} and print <<IAM;

$name is an Ecasound command.  See 'man ecasound-iam'.
IAM
	my @output;
	if ( $help_topic{$name}){
		@output = helptopic($name);
	} elsif ($name !~ /\D/ and $name == 0){
		@output = map{ helptopic $_ } @help_topic;
	} elsif ( $name =~ /^(\d+)$/ and $1 < 20  ){
		@output = helptopic($name)
	} elsif ( $commands{$name} ){
		@output = helpline($name)
	} else {
		my %helped = (); 
		my @help = ();
		map{  
			my $cmd = $_ ;
			if ($cmd =~ /$name/){
				push( @help, helpline($cmd));
				$helped{$cmd}++ ;
			}
			if ( ! $helped{$cmd} and
					grep{ /$name/ } split " ", $commands{$cmd}->{short} ){
				push @help, helpline($cmd) 
			}
		} keys %commands;
		if ( @help ){ push @output, 
			qq("$name" matches the following commands:\n\n), @help;
		}
	}
	if (@output){
		::pager( @output ); 
	} else { print "$name: no help found.\n"; }
	
}
sub help_effect {
	my $input = shift;
	print "input: $input\n";
	# e.g. help tap_reverb    
	#      help 2142
	#      help var_chipmunk # preset


	if ($input !~ /\D/){ # all digits
		$input = $ladspa_label{$input}
			or print("$input: effect not found.\n\n"), return;
	}
	if ( $effect_i{$input} ) {} # do nothing
	elsif ( $effect_j{$input} ) { $input = $effect_j{$input} }
	else { print("$input: effect not found.\n\n"), return }
	if ($input =~ /pn:/) {
		print grep{ /$input/  } @effects_help;
	}
	elsif ( $input =~ /el:/) {
	
	my @output = $ladspa_help{$input};
	print "label: $input\n";
	::pager( @output );
	#print $ladspa_help{$input};
	} else { 
	print "$input: Ecasound effect. Type 'man ecasound' for details.\n";
	}
}


sub find_effect {
	my @keys = @_;
	#print "keys: @keys\n";
	#my @output;
	my @matches = grep{ 
		my $help = $_; 
		my $didnt_match;
		map{ $help =~ /\Q$_\E/i or $didnt_match++ }  @keys;
		! $didnt_match; # select if no cases of non-matching
	} @effects_help;
	if ( @matches ){
# 		push @output, <<EFFECT;
# 
# Effects matching "@keys" were found. The "pn:" prefix 
# indicates an Ecasound preset. The "el:" prefix indicates
# a LADSPA plugin. No prefix indicates an Ecasound chain
# operator.
# 
# EFFECT
	::pager( $text_wrap->paragraphs(@matches) , "\n" );
	} else { print "No matching effects.\n\n" }
}


sub t_load_project {
	package ::;
	return if engine_running() and really_recording();
	my $name = shift;
	print "input name: $name\n";
	my $newname = remove_spaces($name);
	$newname =~ s(/$)(); # remove trailing slash
	print ("Project $newname does not exist\n"), return
		unless -d join_path project_root(), $newname; 
	stop_transport();
	load_project( name => $newname );
	print "loaded project: $project_name\n";
	$debug and print "hook: $::execute_on_project_load\n";
	::command_process($::execute_on_project_load);
		
	
}

    
sub t_create_project {
	package ::;
	my $name = shift;
	load_project( 
		name => remove_spaces($name),
		create => 1,
	);
	print "created project: $project_name\n";

}
sub t_add_ctrl {
	package ::;
	my ($parent, $code, $values) = @_;
	print "code: $code, parent: $parent\n";
	$values and print "values: ", join " ", @{$values};
	if ( $effect_i{$code} ) {} # do nothing
	elsif ( $effect_j{$code} ) { $code = $effect_j{$code} }
	else { warn "effect code not found: $code\n"; return }
	$debug and print "code: ", $code, $/;
		my %p = (
				chain => $cops{$parent}->{chain},
				parent_id => $parent,
				values => $values,
				type => $code,
			);
			#print "adding effect\n";
			# print (yaml_out(\%p));
		add_effect( \%p );
}

sub t_insert_effect {
	package ::;
	my ($before, $code, $values) = @_;
	$code = effect_code( $code );	
	$code = effect_code( $code );
	my $running = engine_running();
	print ("Cannot insert effect while engine is recording.\n"), return 
		if $running and ::really_recording;
	print ("Cannot insert effect before controller.\n"), return 
		if $cops{$before}->{belongs_to};

	if ($running){
		$ui->stop_heartbeat;
		$tn{Master}->mute;		
		eval_iam('stop');
		sleeper( 0.05);
	}
	my $n = $cops{ $before }->{chain} or 
		print(qq[Insertion point "$before" does not exist.  Skipping.\n]), 
		return;
	
	my $track = $ti{$n};
	$debug and print $track->name, $/;
	#$debug and print join " ",@{$track->ops}, $/; 

	# find offset 
	
	my $offset = 0;
	for my $id ( @{$track->ops} ){
		last if $id eq $before;
		$offset++;
	}

	# remove later ops if engine is connected
	# this will not change the $track->cops list 

	my @ops = @{$track->ops}[$offset..$#{$track->ops}];
	$debug and print "ops to remove and re-apply: @ops\n";
	my $connected = eval_iam q(cs-connected);
	if ( $connected ){  
		map{ remove_op($_)} reverse @ops; # reverse order for correct index
	}

	::Text::t_add_effect( $code, $values );

	$debug and print join " ",@{$track->ops}, $/; 

	my $op = pop @{$track->ops}; 
	# acts directly on $track, because ->ops returns 
	# a reference to the array

	# insert the effect id 
	splice 	@{$track->ops}, $offset, 0, $op;
	$debug and print join " ",@{$track->ops}, $/; 

	if ($connected ){  
		map{ apply_op($_, $n) } @ops;
	}
		
	if ($running){
		eval_iam('start');	
		sleeper(0.3);
		$tn{Master}->unmute;
		$ui->start_heartbeat;
	}
}
sub t_add_effect {
	package ::;
	my ($code, $values)  = @_;
	$code = effect_code( $code );	
	$debug and print "code: ", $code, $/;
		my %p = (
			chain => $this_track->n,
			values => $values,
			type => $code,
			);
			#print "adding effect\n";
			$debug and print (yaml_out(\%p));
		add_effect( \%p );
}
sub group_rec { 
	print "Setting group REC-enable. You may record user tracks.\n";
	$tracker->set( rw => 'REC'); }
sub group_mon { 
	print "Setting group MON mode. No recording on user tracks.\n";
	$tracker->set( rw => 'MON');}
sub group_off {
	print "Setting group OFF mode. All user tracks disabled.\n";
	$tracker->set(rw => 'OFF'); } 

sub mixdown {
	print "Enabling mixdown to file.\n";
	$mixdown_track->set(rw => 'REC'); 
	$ecasound_globals_ecs = $ecasound_globals_for_mixdown if 
		$ecasound_globals_for_mixdown; 
}
sub mixplay { 
	print "Setting mixdown playback mode.\n";
	$mixdown_track->set(rw => 'MON');
	$tracker->set(rw => 'OFF');}
	$ecasound_globals_ecs = $ecasound_globals;
sub mixoff { 
	print "Leaving mixdown mode.\n";
	$mixdown_track->set(rw => 'OFF');
	$tracker->set(rw => 'MON')}
	$ecasound_globals_ecs = $ecasound_globals;

sub bunch {
	package ::;
	my ($bunchname, @tracks) = @_;
	if (! $bunchname){
		::pager(yaml_out( \%bunch ));
	} elsif (! @tracks){
		$bunch{$bunchname} 
			and print "bunch $bunchname: @{$bunch{$bunchname}}\n" 
			or  print "bunch $bunchname: does not exist.\n";
	} elsif (my @mispelled = grep { ! $tn{$_} and ! $ti{$_}} @tracks){
		print "@mispelled: mispelled track(s), skipping.\n";
	} else {
	$bunch{$bunchname} = [ @tracks ];
	}
}
