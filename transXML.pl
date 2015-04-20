#!/usr/bin/perl

# use module
use XML::Simple;

# create object
$xml = new XML::Simple;

# read XML file
$fm_file = $ARGV[0];
$data = $xml->XMLin($fm_file, ForceArray => ["function_array", "function", "arg"], KeyAttr => { });

# define special functions
my @aggregate_functions = (
	'ARRAY_AGG',
	'AVG',
	'CORRELATION',
	'COUNT',
	'COUNT_BIG',
	'COVARIANCE',
	'GROUPING',
	'LISTAGG',
	'MAX',
	'MIN',
	'REGR_AVGX',
	'REGR_AVGY',
	'REGR_COUNT',
	'REGR_INTERCEPT',
	'REGR_ICPT',
	'REGR_R2',
	'REGR_SLOPE',
	'REGR_SXX',
	'REGR_SXY',
	'REGR_SYY',
	'STDDEV',
	'SUM',
	'VARIANCE',
	'XMLAGG',
	'XMLGROUP',
);

my @operators = ('+', '-', '*', '/', '<', '>', '<=', '>=', '=', '<>');

my @relational_functions = ('<>', '<', '<=', 'LIKE', '=', '>', '>=');

# read arguement mapping file
my ($filename) = "arg_type_mapping.map";

unless (open (RDH,$filename))
{
    print "The arguement's type mapping file open failed.";
}

my %arg_map = ();
my @key = ();
my @value = ();

for ($knum = 0; my $line = <RDH>; $knum++) {
        my @kstr = split/\ = / ,$line;
        $key[$knum] = $kstr[0];

		$kstr[1] =~ s/\n//g;
        my @vstr = split/\,/,$kstr[1];
        for($vnum = 0; $vnum < scalar(@vstr); $vnum++){
                $value[$knum][$vnum] = $vstr[$vnum];
        }

        $arg_map{$key[$knum]} = $value[$knum];
}
close RDH or die "Cannot close $filename:$!";

# write output file
unless (open (MYFILE, ">$ARGV[1]")) {  
    die ("ERROR! Cannot open output file $ARGV[1]\n");  
    }else{    
    print MYFILE ("<?xml version=\"1.0\"?>\n");  
	print MYFILE ("<function_mappings>\n");
	foreach $e(@{$data->{function_array}}){
		print MYFILE ("\t<function_array lengthname=\"\" name=\"\">\n");
		foreach $f(@{$e->{function}}){
			$num_of_arg = 0;
			$n = 0;
			@array = ();
			@num = (0,0,0,0,0,0,0,0,0,0);
			foreach $h(@{$f->{arg}}){
				$array[$num_of_arg] = $h->{value};
				$num_of_arg++;
			}
			trans_arg();
		}
	print MYFILE ("\t</function_array>\n");
	}
	print MYFILE ("</function_mappings>\n");
}

print "The XML file is transformed successfully.\n";

# define arguements transform function
sub trans_arg{
	for($num[$n] = 0;$num[$n] < scalar(@{$arg_map{$array[$n]}});$num[$n]++){
		if($n < (scalar(@array) - 1)){
			$n++;
            trans_arg($n);
        }else{
			my $string = "";
			my @strs = split/\./,$f->{local_signature}->{value};
            if((grep /^$strs[1]$/, @operators)||($strs[1] eq "+")){
                $string .= "is_operator=\"Y\" ";
            }
            if((grep /^$strs[1]$/, @relational_functions)&&!($strs[1] eq "*")){
                $string .= "is_relational_operator=\"Y\" ";
            }
            if((grep /^$strs[1]$/, @aggregate_functions)&&!($strs[1] eq "*")){
            	$string .= "is_aggregation_function=\"Y\"";
            }
            $f->{name} =~ s/</&lt;/g;
            $f->{name} =~ s/>/&gt;/g;
            print MYFILE ("\t\t<function name=\"",$f->{name},"\" ",$string,">\n");
            $string = "";
            $f->{local_signature}->{value} =~ s/</&lt;/g;
            $f->{local_signature}->{value} =~ s/>/&gt;/g;
            print MYFILE ("\t\t\t<local_signature value=\"",$f->{local_signature}->{value},"\"/>\n");
            $f->{remote_function_name}->{value} =~ s/</&lt;/g;
            $f->{remote_function_name}->{value} =~ s/</&lt;/g;
            print MYFILE ("\t\t\t<remote_function_name value=\"",$f->{remote_function_name}->{value},"\"/>\n");
            $strs[1] =~ s/</&lt;/g;
            $strs[1] =~ s/</&lt;/g;
            print MYFILE ("\t\t\t<pure_name value=\"",$strs[1],"\"/>\n");
            print MYFILE ("\t\t\t<schema value=\"SYSIBM\"/>\n");
            print MYFILE ("\t\t\t<return_type value=\"",$f->{remote_result_type}->{value},"\"/>\n");
            for($i = 0;$i < scalar(@array);$i++){
            	print MYFILE ("\t\t\t<arg value=\"",${$arg_map{$array[$i]}}[$num[$i]],"\"/>\n");
            }
			print MYFILE ("\t\t</function>\n");
        }
  	}
    $n--;

	if(!exists($arg_map{$array[$n]})){
		my $string = "";
        my @strs = split/\./,$f->{local_signature}->{value};
        if((grep /^$strs[1]$/, @operators)||($strs[1] eq "+")){
            $string .= "is_operator=\"Y\" ";
        }
       	if((grep /^$strs[1]$/, @relational_functions)&&!($strs[1] eq "*")){
            $string .= "is_relational_operator=\"Y\" ";
        }
        if((grep /^$strs[1]$/, @aggregate_functions)&&!($strs[1] eq "*")){
            $string .= "is_aggregation_function=\"Y\"";
        }
        $f->{name} =~ s/</&lt;/g;
        $f->{name} =~ s/>/&gt;/g;
        print MYFILE ("\t\t<function name=\"",$f->{name},"\" ",$string,">\n");
        $string = "";
        $f->{local_signature}->{value} =~ s/</&lt;/g;
        $f->{local_signature}->{value} =~ s/>/&gt;/g;
        print MYFILE ("\t\t\t<local_signature value=\"",$f->{local_signature}->{value},"\"/>\n");
        $f->{remote_function_name}->{value} =~ s/</&lt;/g;
        $f->{remote_function_name}->{value} =~ s/</&lt;/g;
        print MYFILE ("\t\t\t<remote_function_name value=\"",$f->{remote_function_name}->{value},"\"/>\n");
        $strs[1] =~ s/</&lt;/g;
        $strs[1] =~ s/</&lt;/g;
        print MYFILE ("\t\t\t<pure_name value=\"",$strs[1],"\"/>\n");
        print MYFILE ("\t\t\t<schema value=\"SYSIBM\"/>\n");
        print MYFILE ("\t\t\t<return_type value=\"",$f->{remote_result_type}->{value},"\"/>\n");
		foreach $h(@{$f->{arg}}){
			print MYFILE ("\t\t\t<arg value=\"",$h->{value},"\"/>\n");
		}
		print MYFILE ("\t\t</function>\n");
	}
}
