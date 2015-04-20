#!/usr/bin/perl
use strict;
use warnings;

use XML_Simple;
use Data::Dumper;

########################### PREFERENCE ############################
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

my @functions_cannot_be_used_after_select = (@relational_functions);

my @functions_cannot_be_used_after_where = (@aggregate_functions);

my %type_data_mapping = (
	'SYSIBM.CHAR' => 'CHA',
	'SYSIBM.VARCHAR' => 'VCH',
	'SYSIBM.INTEGER' => 'ITG',
	'SYSIBM.DECIMAL' => 'DCM',
	'SYSIBM.SMALLINT' => 'SMI',
	'SYSIBM.BIGINT' => 'BGI',
	'SYSIBM.CLOB' => 'CLOB(\'CLOB FOR TEST\')',#
	'SYSIBM.DBCLOB' => 'DBCLOB(\'DBCLOB FOR TEST\')',
	'SYSIBM.BLOB' => 'BLOB(\'BLOB FOR TEST\')',
	'SYSIBM.DATE' => 'DAT',
	'SYSIBM.TIME' => 'TME',
	'SYSIBM.GRAPHIC' => 'GPH',
	'SYSIBM.VARGRAPHIC' => 'VGP',
	'SYSIBM.DECFLOAT' => 'DCF',
	'SYSIBM.DOUBLE' => 'DOB',
	'SYSIBM.TIMESTAMP' => 'TMP',
	'SYSIBM.LONG VARGRAPHIC' => "'LVG'",#
	'SYSIBM.REAL' => 'REL',
	
	
	'SYSIBM.BOOLEAN' => '(1=1)',#
	'NULL' => 'NULL',
	'SYSIBM.LONG VARCHAR' => "'LVC'",#
);

my $db_name = 'PSHDWNDB';
my $wrapper = 'DRDA';
my $srv_name = 'PDSERVER';

my $tb_name = 'T1';
my $nk_name = 'N1';

my %special_functions = (
	'(SYSIBM\.YEAR|SYSIBM\.MONTH|SYSIBM\.DAY|SYSIBM\.HOUR|SYSIBM\.MINUTE|SYSIBM\.SECOND|SYSIBM\.MICROSECOND) \(SYSIBM\.DECIMAL\)' => ["DCM_DATETIME"],
	'(SYSIBM\.YEAR|SYSIBM\.MONTH|SYSIBM\.DAY|SYSIBM\.HOUR|SYSIBM\.MINUTE|SYSIBM\.SECOND|SYSIBM\.MICROSECOND|SYSIBM\.MONTHNAME|SYSIBM\.DAYNAME|SYSIBM\.DAYS) \(SYSIBM\.CHAR\)' => ["CHA_DATETIME"],
	'(SYSIBM\.YEAR|SYSIBM\.MONTH|SYSIBM\.DAY|SYSIBM\.HOUR|SYSIBM\.MINUTE|SYSIBM\.SECOND|SYSIBM\.MICROSECOND|SYSIBM\.MONTHNAME|SYSIBM\.DAYNAME|SYSIBM\.DAYS) \(SYSIBM\.VARCHAR\)' => ["VCH_DATETIME"],
	'(SYSIBM\.CLOB|SYSIBM\.DBCLOB|SYSIBM\.BLOB) \((SYSIBM\.CLOB|SYSIBM\.DBCLOB|SYSIBM\.BLOB), SYSIBM\.INTEGER\)' => ["[ORIGINAL]", "64"],
	'(SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC) \(.+, (SYSIBM\.INTEGER|SYSIBM\.SMALLINT)\)' => ["[ORIGINAL]", "63"],
	'SYSIBM\.CHAR \(SYSIBM\.DECIMAL, (SYSIBM\.CHAR|SYSIBM\.VARCHAR)\)' => ["[ORIGINAL]", "'.'"],
	'(SYSIBM\.INT|SYSIBM\.INTEGER|SYSIBM\.SMALLINT|SYSIBM\.BIGINT|SYSIBM\.FLOAT|SYSIBM\.REAL|SYSIBM\.DOUBLE|SYSIBM\.DECIMAL|SYSIBM\.DEC|SYSIBM\.DECFLOAT) \((SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC)\)' => ["[ORIGINAL]_NUMBER"], #CHA VCH GPH
	'(SYSIBM\.TIME|SYSIBM\.DATE|SYSIBM\.TIMESTAMP) \((SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC)\)' => ["[ORIGINAL]_DATETIME"], #CHA VCH GPH VGP
	'(SYSIBM\.INT|SYSIBM\.INTEGER) \(SYSIBM\.BIGINT\)' => ["BGI_SMALL"],
	'SYSIBM\.SMALLINT \((SYSIBM\.INTEGER|SYSIBM\.BIGINT)\)' => ["[ORIGINAL]_SMALL"], #ITG BGI
	'SYSIBM\.DATE \((SYSIBM\.INTEGER|SYSIBM\.BIGINT|SYSIBM\.DOUBLE|SYSIBM\.DECFLOAT)\)' => ["[ORIGINAL]_DATE"], #ITG BGI DOB DCF
	'SYSIBM\.\* \((SYSIBM\.INTEGER|SYSIBM\.BIGINT), (SYSIBM\.INTEGER|SYSIBM\.BIGINT)\)' => ["[ORIGINAL]_SMALL", "[ORIGINAL]_SMALL"], #ITG BGI
	'SYSIBM\.EXP \(SYSIBM\.BIGINT\)' => ["BGI_SMALL"],
	'(SYSIBM\.ACOS|SYSIBM\.ASIN) \((SYSIBM\.INTEGER|SYSIBM\.BIGINT|SYSIBM\.DECIMAL|SYSIBM\.REAL)\)' => ["[ORIGINAL]_SMALL"], #ITG BGI DCM REL
	'SYSIBM\.POWER \(.+, (SYSIBM\.INTEGER|SYSIBM\.BIGINT)\)' => ["[ORIGINAL]", "[ORIGINAL]_SMALL"], #ITG BGI
	'SYSIBM\.TIMESTAMP \((SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC), SYSIBM\.TIME\)' => ["[ORIGINAL]_DATETIME", "[ORIGINAL]"], #CHA VCH GPH VGP
	'SYSIBM\.TIMESTAMP \(SYSIBM\.DATE, (SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC)\)' => ["[ORIGINAL]", "[ORIGINAL]_DATETIME"], #CHA VCH GPH VGP
	'SYSIBM\.TIMESTAMP \((SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC), (SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC)\)' => ["[ORIGINAL]_DATETIME", "[ORIGINAL]_DATETIME"], #CHA VCH GPH VGP
	'SYSIBM\.TIMESTAMP \(SYSIBM\.DATE, SYSIBM\.INTEGER\)' => ["[ORIGINAL]", "12"],
	'SYSIBM\.TIMESTAMP \((SYSIBM\.CHAR|SYSIBM\.VARCHAR|SYSIBM\.GRAPHIC|SYSIBM\.VARGRAPHIC), SYSIBM\.INTEGER\)' => ["[ORIGINAL]_DATETIME", "12"], #CHA VCH GPH VGP
	'SYSIBM\.TRANSLATE \(.+, .+, .+, .+\)' => ["[ORIGINAL]", "[ORIGINAL]", "[ORIGINAL]", "[ORIGINAL]_ONECHAR"], #CHA VCH GPH VGP
	'(SYSIBM\.LEFT|SYSIBM\.RIGHT|SYSIBM\.SUBSTR|SYSIBM\.TRUNC|SYSIBM\.TRUNCATE|SYSIBM\.ROUND) \([^,]+, SYSIBM\.INTEGER\)' => ["[ORIGINAL]", "[ORIGINAL]_SMALL"], #ITG
	'SYSIBM\.SUBSTR \(.+, .+, .+\)' => ["[ORIGINAL]", "[ORIGINAL]_SMALL", "[ORIGINAL]_SMALL"], #SMI ITG
	'SYSIBM\.SUBSTRB \(SYSIBM\.VARGRAPHIC, SYSIBM\.SMALLINT, SYSIBM\.CHAR\)' => ["[ORIGINAL]", "[ORIGINAL]", "[ORIGINAL]_NUMBER"],
	'SYSIBM\.POSSTR \(.+, (SYSIBM\.CHAR|SYSIBM\.VARCHAR)\)' => ["[ORIGINAL]", "'F'"],
	'SYSIBM\.INSERT \(.+, SYSIBM\.INTEGER, (SYSIBM\.SMALLINT|SYSIBM\.INTEGER), .+\)' => ["[ORIGINAL]", "[ORIGINAL]_SMALL", "[ORIGINAL]_SMALL", "[ORIGINAL]"],
);

=comment

?	SYSIBM.INTEGER (SYSIBM.DATE)
?		SQL0245N The invocation of routine "INTEGER" is ambiguous. The argument in position "1" does not have a best fit. SQLSTATE=428F5

	>>>>> LIKE, GROUPING, DJ_RPAD(db2 stoped) <<<<< (USAGE UNKNOWN FUNCTIONS)
	
	SYSIBM.INTEGER SYSIBM.GROUPING (SYSIBM.DECIMAL) ==> SYSIBM.GROUPING(:1P)
		sql2: select SYSIBM.GROUPING(DCM) from N1
			SQL2 OUTPUT:
			SQL0119N An expression starting with "GROUPING" specified in a SELECT clause, 
			HAVING clause, or ORDER BY clause is not specified in the GROUP BY clause or 
			it is in a SELECT clause, HAVING clause, or ORDER BY clause with a column 
			function and no GROUP BY clause is specified. SQLSTATE=42803
	
	SYSIBM.BOOLEAN SYSIBM.LIKE (SYSIBM.CHAR, SYSIBM.CHAR, SYSIBM.CHAR) ==> (:1P LIKE :2P ESCAPE :3P)
		sql2: select SYSIBM.LIKE(CHA, CHA, CHA) from N1
			SQL2 OUTPUT:
			SQL0130N The ESCAPE clause is not a single character, or the pattern string 
			contains an invalid occurrence of the escape character. SQLSTATE=22019
		sql2: select DOB from N1 where SYSIBM.LIKE(CHA, CHA, CHA)
			SQL2 OUTPUT:
			SQL0104N An unexpected token "END-OF-STATEMENT" was found following 
			".LIKE(CHA, CHA, CHA)". Expected tokens may include: "". 
			SQLSTATE=42601
	
	SYSIBM.VARCHAR SYSIBM.DJ_RPAD (SYSIBM.CHAR, SYSIBM.SMALLINT, SYSIBM.VARCHAR) ==> RPAD(:1P,:2P,:3P)
		SQL1 OUTPUT:
			SQL0901N The SQL statement or command failed because of a database system 
			error. (Reason "Bad Opcode -9, ref_arity 3, sqlnq_pid ID 941 
			(SYSIBM.DJ_RPAD)".) SQLSTATE=58004
		SQL2 OUTPUT:
			SQL1224N The database manager is not able to accept new requests, has 
			terminated all requests in progress, or has terminated the specified request 
			because of an error or a forced interrupt. SQLSTATE=55032
	

	SYSIBM.CHAR SYSIBM.LCASE (SYSIBM.CHAR) ==> SYSIBM.LCASE(:1P)
	SYSIBM.CHAR SYSIBM.LOWER (SYSIBM.CHAR) ==> SYSIBM.LOWER(:1P)
		SQL0901N The SQL statement or command failed because of a database system error. (Reason "RI_BNO_CB: Length mismatch".) SQLSTATE=58004
	
	SYSIBM.DATE SYSIBM.DATE (SYSIBM.DECFLOAT) ==> CAST(:1P AS DATE)
		Phase I	 sql1: select SYSIBM.DATE(DCF_DATE) from T1
		sql2: select SYSIBM.DATE(DCF_DATE) from N1
		Error occurred.
		sql1 (code/status): 0/0
		sql2 (code/status): -1822/560BD
		SQL1 OUTPUT:
		
		1 
		----------
		10/09/1989
		
		1 record(s) selected.
		
		
		SQL2 OUTPUT:
		
		1 
		----------
		SQL1822N Unexpected error code "42846" received from data source "PDSERVER". 
		Associated text and tokens are "func="do_prep" msg=" SQL0461N A value with 
		data type "". SQLSTATE=560BD

NEW TURN:

	Timestamp Format different:
	
	491	SYSIBM.VARCHAR SYSIBM.VARCHAR (SYSIBM.DATE) ==> SYSIBM.VARCHAR(CHAR(CAST(:1P AS DATE),:1K))	hide	show
		Phase I	 sql1: select SYSIBM.VARCHAR(DAT) from T1
		sql2: select SYSIBM.VARCHAR(DAT) from N1
		Result not equal.
		SQL1 OUTPUT:
		
		1 
		----------
		1989-10-09
		
		1 record(s) selected.
		
		
		SQL2 OUTPUT:
		
		1 
		----------
		10/09/1989
		
		1 record(s) selected.
	
	
	493	SYSIBM.VARCHAR SYSIBM.VARCHAR (SYSIBM.TIME) ==> SYSIBM.VARCHAR(CHAR(CAST(:1P AS TIME),:1K))	hide	show
		Phase I	 sql1: select SYSIBM.VARCHAR(TME) from T1
		sql2: select SYSIBM.VARCHAR(TME) from N1
		Result not equal.
		SQL1 OUTPUT:
		
		1 
		--------
		18.45.00
		
		1 record(s) selected.
		
		
		SQL2 OUTPUT:
		
		1 
		--------
		18:45:00
		
		1 record(s) selected.
	
	
	1103	SYSIBM.TIMESTAMP SYSIBM.TIMESTAMP (SYSIBM.VARCHAR, SYSIBM.VARGRAPHIC) ==> SYSIBM.TIMESTAMP(:1P,:2P)	show	hide
		Phase II	 sql1: select DOB from T1 where SYSIBM.TIMESTAMP(VCH_DATETIME, VGP_DATETIME) = '1989-10-09-07.05.30.000000'
		sql2: select DOB from N1 where SYSIBM.TIMESTAMP(VCH_DATETIME, VGP_DATETIME) = '1989-10-09-07.05.30.000000'
		Result not equal.
		SQL1 OUTPUT:
		
		DOB 
		------------------------
		
		0 record(s) selected.
		
		
		SQL2 OUTPUT:
		
		DOB 
		------------------------
		+6.67259000000000E-011
		
		1 record(s) selected.

		
=cut

my %rettyp_calibrations = (
	'(SYSIBM\.SUBSTR|SYSIBM\.SUBSTRB|SYSIBM\.LEFT|SYSIBM\.RIGHT) \([^,]+, .+\)' => "[PARAM]1",
	'SYSIBM\.CONCAT \(.+, .+\)' => "[NONACC]SYSIBM.VARCHAR",
	'SYSIBM\.INSERT \(SYSIBM\.BLOB, SYSIBM\.INTEGER, SYSIBM\.SMALLINT, SYSIBM\.BLOB\)' => "SYSIBM.BLOB",
);

my %DRDA_TYPE_2_SQLZ_TYP = (
	# one to one mapping between SQLQG and SQLNN
	'SYSIBM.CHAR' => 'SQLZ_TYP_CHAR',
	'SYSIBM.VARCHAR' => 'SQLZ_TYP_VARCHAR',
	'SYSIBM.INTEGER' => 'SQLZ_TYP_INTEGER',
	'SYSIBM.DECIMAL' => 'SQLZ_TYP_DECIMAL',
	'SYSIBM.SMALLINT' => 'SQLZ_TYP_SMALL',
	'SYSIBM.BIGINT' => 'SQLZ_TYP_BIGINT',
	'SYSIBM.CLOB' => 'SQLZ_TYP_CLOB',
	'SYSIBM.DBCLOB' => 'SQLZ_TYP_DBCLOB',
	'SYSIBM.BLOB' => 'SQLZ_TYP_BLOB',
	'SYSIBM.DATE' => 'SQLZ_TYP_DATE',
	'SYSIBM.TIME' => 'SQLZ_TYP_TIME',
	'SYSIBM.GRAPHIC' => 'SQLZ_TYP_GRAPHIC',
	'SYSIBM.VARGRAPHIC' => 'SQLZ_TYP_VARGRAPH',
	'SYSIBM.DECFLOAT' => 'SQLZ_TYP_DECFLOAT128',
	'SYSIBM.DOUBLE' => 'SQLZ_TYP_FLOAT',
	'SYSIBM.TIMESTAMP' => 'SQLZ_TYP_STAMP',
	'SYSIBM.LONG VARGRAPHIC' => 'SQLZ_TYP_LONGVARG',
	'SYSIBM.REAL' => 'SQLZ_TYP_FLOAT4',
	
	
	'SYSIBM.BOOLEAN' => 'SQLZ_TYP_BOOLEAN',
	'' => '',
	'' => '',
	'' => '',
	
#	NULL: 26
#	SYSIBM.LONG VARCHAR: 13

#	SQLZ_TYP_LONG: 3
#	SQLZ_TYP_VARBINARY: 27
#	SQLZ_NOTYP: 4
#	SQLZ_TYP_XMLTYPE: 49
#	0: 3
#	SQLZ_TYP_CURSOR: 7
#	SQLZ_TYP_XMLLOB: 8
#	SQLZ_TYP_ARRAY: 16
#	SQLZ_TYP_STRUCT: 5
#	SQLRG_TYP_STRINGLEN_UNIT: 16
#	SQLNQ_UNKNOWN: 523
#	SQLZ_TYP_ROW: 2
);
my %SQLZ_TYP_2_DRDA_TYPE = reverse %DRDA_TYPE_2_SQLZ_TYP;

#$ARGV[0] = 'sqlqg_funcs.lst';
#$ARGV[1] = 'sqlnn_funcs.lst';

my %func_mapping;
open SQLQG_FUNCS_LST, "<", $ARGV[0];
while (<SQLQG_FUNCS_LST>)
{
	chomp;
	
	my ($local_func_schema, $local_func_name, $local_func_argvs, $remote_func) = split /;/;
	my @local_func_argv = split /,/, $local_func_argvs;
	
	#next if $local_func_schema ne "SYSIBM"; # remove in the future.
	
	my $key = "$local_func_schema.$local_func_name";
	my $snd_key = join ",", @local_func_argv;
	
	if (!exists $func_mapping{$key})
	{
		$func_mapping{$key} = {};
	}
	
	if (exists $func_mapping{$key}{$snd_key})
	{
#		printf "SQLQG sig duplicated!\n\t$_\norigin:\n\t%s\n\n", "$key;$snd_key;$func_mapping{$key}{$snd_key}{remote_func}";
	}
	else
	{
		$func_mapping{$key}{$snd_key} = {ret => '', ret_match => 'match failed', remote_func => $remote_func, qg_original_record => $_ };
	}
}
close SQLQG_FUNCS_LST;
#for my $k (keys %func_mapping)
#{
#	print $k, "\n";
#	for my $snd_k (keys %{$func_mapping{$k}})
#	{
#		print "\t$snd_k\n";
#	}
#}

my %sqlnn_func_mapping;
open SQLNN_FUNCS_LST, "<", $ARGV[1];
while (<SQLNN_FUNCS_LST>)
{
	chomp;	
	my ($func_schema, $func_name, $func_ret, $func_argvs) = split /;/;
	my @func_argv = split /,/, $func_argvs;
	
	my $key = "$func_schema.$func_name";
	my $snd_key = join ",", @func_argv;
	
	if (!exists $sqlnn_func_mapping{$key})
	{
		$sqlnn_func_mapping{$key} = {};
	}
	
	if (exists $sqlnn_func_mapping{$key}{$snd_key})
	{
#		printf "SQLNN sig duplicated!\n\t$_\norigin:\n\t%s\n\n", "$key;$sqlnn_func_mapping{$key}{$snd_key}{ret};$snd_key";
	}
	else
	{
		$sqlnn_func_mapping{$key}{$snd_key} = {ret => $func_ret};
	}
}
close SQLNN_FUNCS_LST;
#for my $k (keys %sqlnn_func_mapping)
#{
#	print $k, "\n";
#	for my $snd_k (keys %{$sqlnn_func_mapping{$k}})
#	{
#		print "\t$snd_k\n";
#	}
#}

for my $k (keys %func_mapping)
{
	for my $snd_k (keys %{$func_mapping{$k}})
	{
		my $sqlnn_snd_k = join ",", (map { $DRDA_TYPE_2_SQLZ_TYP{$_} || "[-TYPE-CONVERSION-ERROR-]" } split /,/, $snd_k);
		
		if ($sqlnn_snd_k =~ /TYPE-CONVERSION-ERROR/)
		{
#			print "$k ( $snd_k => $sqlnn_snd_k ) para type conversion error!\n";
			next;
		}
		
		if (!exists $sqlnn_func_mapping{$k})
		{
#			print "$k cannot find this func in SQLNN\n";
			next;
		}
		
		if (!exists $sqlnn_func_mapping{$k}{$sqlnn_snd_k})
		{
#			print "$k ( $snd_k => $sqlnn_snd_k ) cannot find same sig in SQLNN\n";
			next;
		}
		
		if (defined $SQLZ_TYP_2_DRDA_TYPE{$sqlnn_func_mapping{$k}{$sqlnn_snd_k}{ret}})
		{
			$func_mapping{$k}{$snd_k}{ret} = $SQLZ_TYP_2_DRDA_TYPE{$sqlnn_func_mapping{$k}{$sqlnn_snd_k}{ret}};
			$func_mapping{$k}{$snd_k}{ret_match} = 'accurate';
		}
		else
		{
			$func_mapping{$k}{$snd_k}{ret_match} = 'accurate | conversion failed';
#			printf "(%s => %s) $k ( $snd_k => $sqlnn_snd_k ) ret type conversion error!\n", $func_mapping{$k}{$snd_k}{ret}, $sqlnn_func_mapping{$k}{$sqlnn_snd_k}{ret};
		}
	}
}

#&showParsedRatio (%func_mapping);

my %sqlnn_func_para_num_mapping;

for my $k (keys %sqlnn_func_mapping)
{
	$sqlnn_func_para_num_mapping{$k} = {};
	for my $snd_k (keys %{$sqlnn_func_mapping{$k}})
	{
		my $para_num = split /,/, $snd_k;
		
		if (!exists $sqlnn_func_para_num_mapping{$k}{$para_num})
		{
			$sqlnn_func_para_num_mapping{$k}{$para_num} = {ret => $sqlnn_func_mapping{$k}{$snd_k}{ret}, conflict => 0};
		}
		else
		{
			if ($sqlnn_func_para_num_mapping{$k}{$para_num}{ret} ne $sqlnn_func_mapping{$k}{$snd_k}{ret})
			{
#				printf "%s $k ($para_num) has another ret type %s different from current one.\n", $sqlnn_func_para_num_mapping{$k}{$para_num}{ret}, $sqlnn_func_mapping{$k}{$snd_k}{ret};
				$sqlnn_func_para_num_mapping{$k}{$para_num}{conflict}++;
			}
		}
	}
}

for my $k (keys %func_mapping)
{
	for my $snd_k (keys %{$func_mapping{$k}})
	{
		if ($func_mapping{$k}{$snd_k}{ret_match} eq "match failed")
		{
			if (!exists $sqlnn_func_para_num_mapping{$k})
			{
#				print "$k cannot find this func in SQLNN\n";
				next;
			}
			
			my $para_num = split /,/, $snd_k;
			
			if (!exists $sqlnn_func_para_num_mapping{$k}{$para_num})
			{
#				print "$k ( $snd_k <para_num: $para_num> ) cannot find sig with same num of paras in SQLNN\n";
				next;
			}
			
			if (defined $SQLZ_TYP_2_DRDA_TYPE{$sqlnn_func_para_num_mapping{$k}{$para_num}{ret}})
			{
				$func_mapping{$k}{$snd_k}{ret} = $SQLZ_TYP_2_DRDA_TYPE{$sqlnn_func_para_num_mapping{$k}{$para_num}{ret}};
				$func_mapping{$k}{$snd_k}{ret_match} = 'fuzzy';
				
				if ($sqlnn_func_para_num_mapping{$k}{$para_num}{conflict})
				{
					$func_mapping{$k}{$snd_k}{ret_match} .= ' | conflicted';
#					print "$k ( $snd_k <para_num: $para_num> ) cannot parse by para num for the conflict in SQLNN\n";
				}
			}
			else
			{
				$func_mapping{$k}{$snd_k}{ret_match} = 'fuzzy | conversion failed';
#				printf "(%s => %s) $k ( $snd_k <para_num: $para_num> ) ret type conversion error!\n", $func_mapping{$k}{$snd_k}{ret}, $sqlnn_func_para_num_mapping{$k}{$para_num}{ret};
			}
		}
	}
}

#&showParsedRatio (%func_mapping);

############################################ PARSE END #####################################################

my $id = 0;
my @rows;
my $all_func_num = 0;

for my $func_schema_name (keys %func_mapping)
{
	for my $func_argvs (keys %{$func_mapping{$func_schema_name}})
	{
		$all_func_num++;
	}
}

#print "The approximate number of functions to be varified: $all_func_num\n";

=comment
for my $func_schema_name (keys %func_mapping)
{
	print "$func_schema_name\n";
	for my $func_argvs (keys %{$func_mapping{$func_schema_name}})
	{
		my @func_argv = split /,/, $func_argvs;
		my $func_ret = $func_mapping{$func_schema_name}{$func_argvs}{ret};
		my $remote_func = $func_mapping{$func_schema_name}{$func_argvs}{remote_func};
		
		printf "%-100s%-25s%s\n", "\t". (join "*", @func_argv). "->$func_ret",$func_mapping{$func_schema_name}{$func_argvs}{ret_match}, $remote_func;
	}
}
=cut

my $function_mappings = {};

$function_mappings->{brief} = { content => "" };
$function_mappings->{long} = { content => "" };

$function_mappings->{prefix} = { content => "" };

$function_mappings->{public_header} = [ "", "" ];
$function_mappings->{private_header} = [ "", "" ];

$function_mappings->{function_array} = [];

my $function_array = {};

$function_array->{name} = "";
$function_array->{lengthname} = "";
$function_array->{long} = { content => "" };
$function_array->{function} = [];

push @{$function_mappings->{function_array}}, $function_array;

for my $func_schema_name (keys %func_mapping)
{
	for my $func_argvs (keys %{$func_mapping{$func_schema_name}})
	{
		if ($func_mapping{$func_schema_name}{$func_argvs}{ret} eq "")
		{
			$all_func_num--;
			next;
		}
		
		++$id;
		
		#next if $id < 1670;
		
		#goto END if $id > 250;
		
		my $func = {}; #<==
		
		my ($func_schema, $func_name) = split /\./, $func_schema_name;
		my @func_argv = split /,/, $func_argvs;
		my $func_ret = $func_mapping{$func_schema_name}{$func_argvs}{ret};
		my $remote_func = $func_mapping{$func_schema_name}{$func_argvs}{remote_func};
		my $qg_original_record = $func_mapping{$func_schema_name}{$func_argvs}{qg_original_record};
		
		$func->{name} = $func_schema_name; #<==
		$func->{local_signature} = { value => $func_schema_name }; #<==
		$func->{schema} = { value => $func_schema }; #<==
		$func->{pure_name} = { value => $func_name }; #<==
		$func->{arg} = []; #<==
		$func->{remote_function_name} = { value => $remote_func }; #<==
		
		push @{$func->{arg}}, map { { value => $_ } } @func_argv; #<==
		
		my $func_sig = sprintf "%s.%s (%s)", $func_schema, $func_name, (join ", ", @func_argv);
		
		for my $k (keys %rettyp_calibrations)
		{
			if ($func_sig =~ /$k/)
			{
				if ($rettyp_calibrations{$k} =~ /^\[PARAM\](\d+)$/)
				{
					$func_ret = ($1 > 0 && @func_argv >= $1) ? $func_argv[$1 -1] : "[PARAM-INDEX-OUT-OF-RANGE]";
				}
				elsif ($rettyp_calibrations{$k} =~ /^\[NONACC\](.+)$/)
				{
					$func_ret = $1 if ($func_mapping{$func_schema_name}{$func_argvs}{ret_match} ne "accurate");
				}
				else
				{
					$func_ret = $rettyp_calibrations{$k};
				}
				last;
			}
		}
		
		$func->{return_type} = { value => $func_ret }; #<==
#		print "---------------------------------------------------------------------------------------------------------------------------------------\n";
#		printf "%-110s", $qg_original_record;
		
		$func->{test_arg} = [];
		
		my @args_array;
		my $is_special_function = 0;
		
		for my $k (keys %special_functions)
		{
			if ($func_sig =~ /$k/)
			{
				$is_special_function = 1;
				
				@args_array = 
				map
				{
					if (${$special_functions{$k}}[$_] =~ /\[ORIGINAL\]/)
					{
						(my $tmp = ${$special_functions{$k}}[$_]) =~ s/\[ORIGINAL\]/$type_data_mapping{$func_argv[$_]}/g;
						
						if ($tmp ne $type_data_mapping{$func_argv[$_]})                  #<==
						{                                                                #<==
							push @{$func->{test_arg}}, { pos => $_ + 1, content => $tmp }; #<==
						}                                                                #<==

						$tmp;
					}
					else
					{
						push @{$func->{test_arg}}, { pos => $_ + 1, content => ${$special_functions{$k}}[$_] }; #<==
						
						${$special_functions{$k}}[$_];
					}
				} (0 .. @{$special_functions{$k}} - 1);
				
				last;
			}
		}
		
#		print join ", ", @args_array;
		
#		print "\n---------------------------------------------------------------------------------------------------------------------------------------\n";
		
		if (grep {$func_name eq $_} @operators)
		{
			$func->{is_operator} = "Y"; #<==
		}
		
		if (grep {$func_name eq $_} @functions_cannot_be_used_after_select)
		{
			$func->{is_relational_operator} = "Y"; #<==
		}
		
		if (grep {$func_name eq $_} @functions_cannot_be_used_after_where)
		{
			$func->{is_aggregation_function} = "Y"; #<==
		}
		
#		$func->{disable} = "N";
#		$func->{skip_push_down_test} = "N";
		
		push @{$function_array->{function}}, $func;
		
#		print Dumper ($func);
	
	}
}
	
END:

my $function_mappings_xml = &XML::Simple::XMLout
(
	$function_mappings,
	ValueAttr => {},
	ContentKey => "content",
	RootName => "function_mappings",
#	NoSort => 1,
);

#print $function_mappings_xml;
unless (open (MYFILE, ">$ARGV[2]")) {
	die ("ERROR! Cannot open output file $ARGV[2]\n");
	}else{
	print MYFILE $function_mappings_xml;
	}

exit 0;

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub getFirstLine
{
	my ($string) = shift;
	if (index ($string, "\n") != -1)
	{
		return substr $string, 0, (index $string, "\n");
	}
	return $string;
}

sub showParsedRatio
{
	my %func_mapping = @_;
	
	my ($i, $j) = (0, 0);
	for my $k (keys %func_mapping)
	{
		for my $snd_k (keys %{$func_mapping{$k}})
		{
			if ($func_mapping{$k}{$snd_k}{ret} ne "")
			{
				++$i;
# 				printf "%4d: %s $k ( $snd_k )  ->  %s\n", $i, $func_mapping{$k}{$snd_k}{ret}, $func_mapping{$k}{$snd_k}{remote_func};
			}
			++$j;
		}
	}
	printf "parsed ratio: %.2f%%\n", $i / $j * 100;
}

sub wrapData
{
	my ($type_name, $data) = @_;
	
	return "$data"				if $type_name eq 'NULL';
	return "$data"				if $type_name eq 'SYSIBM.BOOLEAN';
	
	if ($type_name eq 'SYSIBM.BLOB')
	{
		return "blob($data) " if $data =~ /^'.*'$/ || $data =~ /^x'.*'$/;
		return "blob('$data')";
	}
	
	if ($type_name eq 'SYSIBM.DECFLOAT')
	{
		if (length $data > 30)
		{
			if ($data =~ /^(.+?)([Ee].*)?$/)
			{
				return (substr $1, 0, 30 - length $2). $2;
			}
			return "[NUMBER-CONVERSION-ERROR]"
		}
		return "$data";
	}
	
	return "$data"				if $type_name eq 'SYSIBM.SMALLINT';
	return "$data"				if $type_name eq 'SYSIBM.INTEGER';
	return "$data"				if $type_name eq 'SYSIBM.BIGINT';
	return "$data"				if $type_name eq 'SYSIBM.DECIMAL';
	return "$data"				if $type_name eq 'SYSIBM.REAL';
	return "$data"				if $type_name eq 'SYSIBM.DOUBLE';
	
	$data =~ s/'/''/g;
	
	return "'$data'"			if $type_name eq 'SYSIBM.CHAR';
	return "'$data'"			if $type_name eq 'SYSIBM.VARCHAR';
	return "'$data'"			if $type_name eq 'SYSIBM.GRAPHIC';
	return "'$data'"			if $type_name eq 'SYSIBM.VARGRAPHIC';
	return "'$data'"			if $type_name eq 'SYSIBM.LONG VARCHAR';
	return "'$data'"			if $type_name eq 'SYSIBM.LONG VARGRAPHIC';
	return "clob('$data')"		if $type_name eq 'SYSIBM.CLOB';
	return "dbclob('$data')"	if $type_name eq 'SYSIBM.DBCLOB';
	return "'$data'"			if $type_name eq 'SYSIBM.TIME';
	return "'$data'"			if $type_name eq 'SYSIBM.DATE';
	return "'$data'"			if $type_name eq 'SYSIBM.TIMESTAMP';
	
	return "[UNKNOWN]";
}
