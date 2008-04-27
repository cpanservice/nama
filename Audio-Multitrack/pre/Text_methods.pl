use Carp;
#&loop;
sub new { my $class = shift; return bless { @_ }, $class; }
sub loop {
package ::;
load_project({name => $project_name, create => $opts{c}}) if $project_name;
use Parse::RecDescent;
use Term::ReadLine;
my $term = new Term::ReadLine 'Ecmd';
my $prompt = "Enter command: ";
$OUT = $term->OUT || \*STDOUT;
my $user_input;
$parser = new Parse::RecDescent ($grammar) or croak "Bad grammar!\n";
$debug = 1;
	while (1) {
		my ($user_input) = $term->readline($prompt) ;
		$user_input =~ /^\s*$/ and next;
		$term->addhistory($user_input) ;
		my ($cmd, $predicate) = ($user_input =~ /(\S+)(.*)/);
		$debug and print "cmd: $cmd \npredicate: $predicate\n";
		if ($cmd eq 'eval') {
			eval $predicate;
			print "\n";
			$@ and print "Perl command failed: $@\n";
		} elsif ($tn{$cmd}) { 
			$debug and print "Track name: $cmd\n";
			$select_track = $tn{$cmd};
			print "selected: $cmd\n";
			$parser->command($predicate) or print ("Returned false\n");
		} elsif ($iam_cmd{$cmd}){
			$debug and print "Found IAM command\n";
			eval_iam($user_input) ;
		} else {
			$parser->command($user_input) 
				and print("Succeeded\n") or print ("Returned false\n");

		}
	}
}

format STDOUT_TOP =
Chain Ver File            Setting Status Rec_ch Mon_ch 
=====================================================
.
format STDOUT =
@<<  @<<  @<<<<<<<<<<<<<<<  @<<<   @<<<   @<<    @<< ~~
splice @::format_fields, 0, 7

.
	
1;