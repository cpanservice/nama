## TODO
=comment
I have to get my Wav test environment back:
	
	UI.p including Session_Wav.pl with stubs

	2_Wav.t including tests for Wavs. 



Once we have set $session_name, everything starts
happening. Conversely, nothing can happen without
a session_name. We coudl have session objects, consisting
of only a name. But how would that help? Each
object is actually represented by a pair of directories.
in wav_dir/my_gig and in wav_dir/.ecmd/my_gig

=cut


## The following methods belong to the Session class

#my $s = Session->new(name => 'paul_brocante');
# print $s->session_dir;

package ::Session;
our @ISA='::';
use Carp;
use Object::Tiny qw(name);
sub hello {"i'm a session"}
=comment
	$session = remove_spaces($session); # internal spaces to underscores
	$session_name = $hash->{name} ? $hash->{name} : $session;
	$hash->{create} and 
		print ("Creating directories....\n"),
=cut
sub new { 
	my $class = shift; 
	my %vals = @_;
	$vals{name} or carp "invoked without values" and return;
	my $name = remove_spaces( $vals{name} );
	$vals{name} = join_path($name;
	if ($vals{create_dir}){
		my 
		map{create_dir} &this_wav_dir, &session_dir;
		-e $name
		create_dir($name) and delete $vals{create_dir};
	return bless { %vals }, $class;
}

sub session_dir { 
	my $self = shift;
	join_path( &ecmd_home, $self->name);
}
sub this_wav_dir {
	my $self = shift;
	join_path( &wav_dir, $self->name);
}


sub set {
	my $self = shift;
 	croak "odd number of arguments ",join "\n--\n" ,@_ if @_ % 2;
	my %new_vals = @_;
	my %filter;
	map{$filter{$_}++} keys %{ $self };
	map{ $self->{$_} = $new_vals{$_} if $filter{$_} 
		or carp "illegal key: $_ for object of type ", ref $self,$/
	} keys %new_vals;
}
sub explode {  
# will not work for unversioned  vocal.wav
	my $wav = shift;
	map{  UI::Wav->new(head => $_) 

		} map{ s/.wav$//i; $_} 

			@{ [ values %{ $wav->targets } ] }
}

# package Track
# usage: Track->new( WAV = [$vocal->explode] );
# usage: Track->new( WAV = $vocal );
# $vocal is a Wav,

# following for objects to polymorph in taking 
# arrays or array refs.
sub deref_ {
	my $ref = shift;
	@_ = @{ $ref } if ref $_[0] =~ /ARRAY/;
}


## aliases 

sub wav_dir {UI::wav_dir() }
sub ecmd_dir { UI::ecmd_dir() }
sub this_wav_dir { UI::this_wav_dir() }
sub session_dir { UI::session_dir() }
sub remove_spaces { UI::remove_spaces() }

package ::Wav;
our @ISA='UI';
use Object::Tiny qw(head active n);
my @fields = qw(head active n);
my %fields;
map{$fields{$_} = undef} @fields;
use Carp;
sub this_wav_dir { UI::this_wav_dir() }
sub new { my $class = shift; 
 		croak "odd number of arguments ",join "\n--\n" ,@_ if @_ % 2;
		 return bless {%fields, @_}, $class }

sub _get_versions {
	my ($dir, $basename, $sep, $ext) = @_;

	$debug and print "getver: dir $dir basename $basename sep $sep ext $ext\n\n";
	opendir WD, $dir or carp ("can't read directory $dir: $!");
	$debug and print "reading directory: $dir\n\n";
	my %versions = ();
	for my $candidate ( readdir WD ) {
		$debug and print "candidate: $candidate\n\n";
		$candidate =~ m/^ ( $basename 
		   ($sep (\d+))? 
		   \.$ext )
		   $/x or next;
		$debug and print "match: $1,  num: $3\n\n";
		$versions{ $3 ? $3 : 'bare' } =  $1 ;
	}
	$debug and print "get_version: " , yaml_out(\%versions);
	closedir WD;
	%versions;
}

sub targets {# takes a Wav object or a string (filename head)
	local $debug = 1;
	my $wav = shift; 
 	my $head =  ref $wav ? $wav->head : $wav;
	$debug2 and print "&targets\n";
	local $debug = 0;
	$debug and ($t = this_wav_dir()), print 
"this_wav_dir: $t
head:         ", $head, $/;
		my %versions =  _get_versions(
			this_wav_dir(),
			$head,
			'_', 'wav' )  ;
		if ($versions{bare}) {  $versions{1} = $versions{bare}; 
			delete $versions{bare};
		}
	$debug and print "\%versions\n================\n", yaml_out(\%versions);
	\%versions;
}
sub versions {  # takes a Wav object or a string (filename head)
	my $wav = shift;
	if (ref $wav){ [ sort { $a <=> $b } keys %{ $wav->targets} ] } 
	else 		 { [ sort { $a <=> $b } keys %{ targets($wav)} ] }
}

sub this_last { 
	my $wav = shift;
	pop @{ $wav->versions} }

sub _selected_version {
	# return track-specific version if selected,
	# otherwise return global version selection
	# but only if this version exists
	my $wav = shift;
no warnings;
	my $version = 
		$wav->active 
		? $wav->active 
		: &monitor_version ;
	(grep {$_ == $version } @{ $wav->versions} ) ? $version : undef;
	### or should I give the active version
use warnings;
}
=comment
sub last_version { 
	## for each track or tracks in take

$track->last_version;
$take->last_version
$session->last_version
	
			$last_version = $this_last if $this_last > $last_version ;

}

sub new_version {
	last_version() + 1;
}
=cut

=comment
my $wav = Wav->new( head => vocal);

$wav->versions;
$wav->head  # vocal
$wav->n     # 3 i.e. track 3
$wav->active
$wav->targets
$wav->full_path

returns numbers

$wav->targets

returns targets

=cut

