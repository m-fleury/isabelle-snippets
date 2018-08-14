use strict;
use warnings;

use Data::Dumper;
use List::Flatten;
use Getopt::Long;

my @symbol_files;
my $verbose = 0;
my $out_file;


GetOptions(
    "file=s@" => \@symbol_files,
    "out_file=s" => \$out_file,
    "verbose=i"=> \$verbose,
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
    if($symbol{abbrev}) {
	foreach my $abbrev (@{$symbol{abbrev}})
	{
	    my $escaped_body = $symbol{symbol};
	    if($symbol{argument} && $symbol{argument} eq "cartouche") {
		$escaped_body .= "\<open>$0\<close>"
	    }
	    my $escaped_abbrev = $abbrev;

	    my $escaped_symbol = $symbol{symbol};


	    $escaped_body =~ s/\\/\\\\/g;
	    $escaped_abbrev =~ s/\\/\\\\/g;
	    $escaped_symbol =~ s/\\/\\\\/g;

	    my $entry = <<END
	 "$escaped_symbol `$escaped_abbrev`": {
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
      - the <SYMBOL_FILE> can be found by `isabelle env | grep "ISABELLE_SYMBOLS"` (if isabelle is in your path)
      - the <SNIPPET_FILE> is overwritten

  BEWARE: the SNIPPET_FILE is overwritten.
END
}