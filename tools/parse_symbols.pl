use strict;
use warnings;

use Data::Dumper;
use List::Flatten;
use Getopt::Long;

my @symbol_files;
my $verbose = 0;
my $out_file;
my $complete_by_cartouches = 1;
my $complete_cartouche_group = 1;

GetOptions(
    "file=s@" => \@symbol_files,
    "out_file=s" => \$out_file,
    "verbose=i"=> \$verbose,
    "complete_by_cartouches!" => \$complete_by_cartouches,
    "complete_cartouche_group!" => \$complete_cartouche_group,
    "help" => sub {print_usage(); exit});

my @symbols;


foreach my $symbol_file (@symbol_files)
{
    open(my $fh, "<", $symbol_file)
	or die "Can't open < $symbol_file: $!";

    foreach my $line (<$fh>)
    {
	if ($line =~ /^#/ || length($line) == 1)
	{

	}

	else
	{
	    if ($line =~ /.*\n/) {
		chomp $line
	    }
	    $line =~ s/(.*) code: (.*)/$1  code: $2/g; #in some cases there is a missing space in etc/symbols
	    my ($symbol_name, @props) =  split(/ {2,}/, $line);
	    my %symbol = ();
	    $symbol{symbol} = $symbol_name;

	    foreach my $def_value (@props)
	    {

		my ($def, $value) = split(/: /, $def_value);
		if($def eq "abbrev") {
		    my @abbrevs = $symbol{$def} ? @{$symbol{$def}} : ();
		    push @abbrevs, $value;
		    $symbol{$def} = \@abbrevs;
		} else {
		    $symbol{$def} = $value;
		}
	    }
	    if($verbose >= 3) {
		print "\n$symbol_name ~~~>\n";
		foreach(keys %symbol)
		{
		    if($_ eq "abbrev") {
			print "\t$_: @{$symbol{$_}}\n";
		    } else {
			print "\t$_: $symbol{$_}\n";
		    }
		}
	    }
	    push @symbols, \%symbol;
	}
    }
    close $fh
}



open(my $fh, ">", $out_file)
    or die "Can't open < $out_file: $!";

print $fh "{\n";

for (@symbols)
{
    my %symbol = %$_;
    if($complete_cartouche_group &&
       $symbol{argument} &&
       ($symbol{argument} eq "cartouche" || $symbol{argument} eq "space_cartouche") &&
       !$symbol{abbrev}) {
	my $abbrev = $symbol{symbol};

	#take only the 3 first letters and remove the '<' and '>'
	$abbrev =~ s/\\<\^(.{3}).*>/\\$1/;
	$abbrev =~ s/\\<(.{3}).*>/\\$1/;
	my @abbrevs = ($abbrev);
	$symbol{abbrev} = \@abbrevs
    }

    if($symbol{abbrev}) {
	my $number_of_abbrevs = @{$symbol{abbrev}};
	foreach my $abbrev (@{$symbol{abbrev}})
	{
	    my $escaped_body = $symbol{symbol};
	    if($complete_by_cartouches &&
	       $symbol{argument} && $symbol{argument} eq "cartouche") {
		$escaped_body .= "\\<open>\$0\\<close>"
	    }

	    if($complete_by_cartouches &&
	       $symbol{argument} && $symbol{argument} eq "space_cartouche") {
		$escaped_body .= " \\<open>\$0\\<close>"
	    }
	    my $escaped_abbrev = $abbrev;

	    my $escaped_symbol = $symbol{symbol};


	    # now properly escape the strings
	    $escaped_body =~ s/\\/\\\\/g;
	    $escaped_abbrev =~ s/\\/\\\\/g;
	    $escaped_symbol =~ s/\\/\\\\/g;

	    my $name = $escaped_symbol . ($number_of_abbrevs == 1 ? "" : " `$escaped_abbrev`");
	    my $entry = <<END
        "$name": {
	   "prefix": "$escaped_abbrev",
	   "body": "$escaped_body",
	   "description": "$escaped_symbol (Isabelle/jEdit symbol)"
	},
END
		;
	    print $fh $entry;
	}
    }

}

print $fh "}";
close $fh;


sub print_usage()

{
    print <<END
  This program parse the etc/symbols file from isabelle to produce the
  abbreviation as a snippet file usabel by VSCode.

  Usage:
       perl ./parse_symbols.pl --file=<SYMBOL_FILE> --out_file=<SNIPPET_FILE>
    where
      - the <SYMBOL_FILE> can be found by
         `isabelle env | grep "ISABELLE_SYMBOLS"` (if isabelle is in your path)
      - the <SNIPPET_FILE> is overwritten

  Additional options:
     --complete_cartouche_group (or --nocomplete_cartouche_group) decides whether
       elements without abbreviation from the groups 'cartouche' or 'space_cartouche'
       should be included (e.g., \ter ~> \<^term>).
     --complete_by_cartouches (or --nocomplete_by_quotes) decides whether elements
       from group 'cartouche' or 'space_cartouche' should be automatically completed
       by cartouches (e.g., \ter ~> \<^term>\<open>$0\<close> where $0 is the new
       position of the cursor).

  BEWARE: the SNIPPET_FILE is overwritten.
END
}