#!/usr/bin/perl

use warnings;
use strict;

use XML_Simple;
use Data::Dumper;


#
# Exit Codes:
#
#   0: Normal
#   1: Missing function mapping file.
#   2: Cannot access function mapping file.
#   3: Read function mapping file error.
#   4: function mapping file is empty.
#   
#   
#   
#   
#   10: Parse function mapping file Error
#

my $debug_enabled = 0;

my $test_cfg =
{
	# Pre-test recording
	record_system_info => 1,
	record_environment => 1,
	record_dbm_config => 1,
	record_db_configs => 1,
	record_db2set => 1,
	record_info_directory_path => "info",
	
	# In-test recording
	record_db2exfmt_plan => 1,
	db2exfmt_plan_directory_path => "plan",
	
	# In-test processing configurations
	check_function_elimination => 1,
	trace_for_internal_func => 1,
	trace_for_internal_func_mask => "*.*.SQLNQ.sqlnq_sat::get_remote_function.*",
	trace_directory_path => "trace",
};

my $output_cfg =
{
	# Report related configurations
	report_mainpage_template_path => "report_res/mainpage.html",
	report_table_template_path => "report_res/table.html",
	report_row_template_path => "report_res/row.html",
	report_directory_path => "report",
	
	generate_temporary_report => 1,
	temporary_report_frequency => 10, # Cannot be 0 at here.
	temporary_report_filename => "temp.html",
	
	final_report_filename => "final.html",
};

my $db_cfg =
{
	feddb_name => "FEDDB",
	remdb_name => "DSDB",
	feddb_schema => "IIFVT66",
	remdb_schema => "IIFVT66",
	
	wrapper => "DRDA",
	srv_name => "PDSERVER",
	
	tb_name => "T1",
	nk_name => "N1",
};

###############################################################
## ignore_sql_error_code_only_for_table                      ##
##                                                           ##
##     When sql code of "select ... from [table]" statement  ##
##     less than zero but the other sql code equals to zero, ##
##     then result will be trated as succeed, and the select ##
##     result will be the result of the other statement.     ##
##                                                           ##
###############################################################
my @ignore_sql_error_code_only_for_table = (
	-3324, #SQL3324N Column "x" has a type of "xLOB" which is not recognized. (only table)
);

###############################################################
## ignore_sql_error_code_only_for_nickname                   ##
##                                                           ##
##     When sql code of "select ... from [nick]" statement   ##
##     less than zero but the other sql code equals to zero, ##
##     then result will be trated as succeed, and the select ##
##     result will be the result of the other statement.     ##
##                                                           ##
###############################################################
my @ignore_sql_error_code_only_for_nickname = (
);

###############################################################
## ignored_sql_error_codes_once_seen_table                   ##
##                                                           ##
##     When sql code of "select ... from [table]" statement  ##
##     was equal to the given code, then result will be      ##
##     trated as ignored, and the select result will be      ##
##     empty.                                                ##
##                                                           ##
###############################################################
my @ignored_sql_error_codes_once_seen_table = (
);

###############################################################
## ignored_sql_error_codes_once_seen_nickname                ##
##                                                           ##
##     When sql code of "select ... from [nick]" statement   ##
##     was equal to the given code, then result will be      ##
##     trated as ignored, and the select result will be      ##
##     empty.                                                ##
##                                                           ##
###############################################################
my @ignored_sql_error_codes_once_seen_nickname = (
);

###############################################################
## ignored_sql_error_codes_both                              ##
##                                                           ##
##     When sql code of both statements were equal to the    ##
##     given code, then result will be trated as ignored,    ##
##     and the select result will be empty.                  ##
##                                                           ##
###############################################################
my @ignored_sql_error_codes_both = (
	-120, #SQL0120N  Invalid use of an aggregate function or OLAP function. (both)
);

# Global variables for report generating.
my $report_mainpage_template;
my $report_table_template;
my $report_row_template;


sub main
{
	######################################################################
	# STEP 1: Read function mapping file.
	######################################################################
	
	# $fm_file: function mapping file.
	my $fm_file = $ARGV[0];
	unless (defined $fm_file && $fm_file ne "")
	{
		print STDERR <<USAGE;
Usage:

    $0 <XML_FILE_PATH>

USAGE
		exit 1;
	}
	
	# $fm_fh: function mapping file handle.
	open my ($fm_fh), "<", $fm_file or do
	{
		print STDERR "[ERROR]Cannot access \"$fm_file\": $!.\n";
		exit 2;
	};
	
	# $fm_content: all the content of the function mapping file.
	my $fm_content = do { local $/; readline $fm_fh };
	
	if (!defined $fm_content)
	{
		print STDERR "[ERROR]Read file \"$fm_file\" error.\n";
		exit 3;
	}
	
	if(length $fm_content <= 0)
	{
		print STDERR "[ERROR]File \"$fm_file\" is empty.\n";
		exit 4;
	}
	
	close $fm_fh;
	
	print ("[INFO]Read file \"$fm_file\" succeed.\n");
	
	
	######################################################################
	# STEP 2: Parse function mapping file.
	######################################################################
	
	# Verify XML format (TODO)
	
	# Parse XML to DOM (represented by hash ref).
	# $fm_dom_root: root of function mapping document object model
	my $fm_dom_root = XML::Simple::XMLin (
		$fm_content,
		ContentKey => "-content",
		ForceArray => ["function_array", "function", "arg", "test_arg"],
		KeyAttr => { test_arg => "pos" },
		ValueAttr => ["value"],
	);
	
	&debug (Dumper ($fm_dom_root));
	
	print ("[INFO]Parse file succeed.\n");
	
	exit 0 if $debug_enabled;
	
	######################################################################
	# STEP 3: Get function list for push down testing.
	######################################################################
	my @function_list;
	
	my @function_arrays = @{$fm_dom_root->{function_array}};
	for (@function_arrays)
	{
		my @functions = @{$_->{function}};
		for (@functions)
		{
			&debug ("$_->{name}\n");
			
			unless (defined $_->{skip_push_down_test} && $_->{skip_push_down_test} =~ /^Y(ES)?$/i)
			{
				push @function_list, $_;
			}
		}
	}
	
	my $function_list_size = scalar @function_list;
	
	print "[INFO]Get function list succeed, there are $function_list_size functions to be tested.\n";
	
	
	######################################################################
	# STEP 4: Pre-testing operations.
	######################################################################
	
	# Prepare DB (TODO)
	&prepareDB;
	
	# Initialize Report Templates
	&initReportTemplates;
	
	# Prepare Report Directory
	if (!-d $output_cfg->{report_directory_path})
	{
		system ("mkdir -p $output_cfg->{report_directory_path}");
	}
	
	# Prepare Record Directory
	if (($test_cfg->{record_system_info} || $test_cfg->{record_environment}
			|| $test_cfg->{record_dbm_config} || $test_cfg->{record_db_configs}
			|| $test_cfg->{record_db2set}) && !-d $test_cfg->{record_info_directory_path})
	{
		system ("mkdir -p $test_cfg->{record_info_directory_path}");
	}
	
	# Prepare db2exfmt Plan Directory
	if ($test_cfg->{record_db2exfmt_plan} && !-d $test_cfg->{db2exfmt_plan_directory_path})
	{
		system ("mkdir -p $test_cfg->{db2exfmt_plan_directory_path}");
	}
	
	# Prepare Trace Directory
	if ($test_cfg->{trace_for_internal_func} && !-d $test_cfg->{trace_directory_path})
        {
                system ("mkdir -p $test_cfg->{trace_directory_path}");
        }
	
	
	######################################################################
	# STEP 5: Test.
	######################################################################
	my $id = 0;
	my @rows;
	
	for (@function_list)
	{
		$id++;
		
		&pushDownTest ($id, $_, \@rows, $function_list_size);
		
		if ($output_cfg->{generate_temporary_report} && $id % $output_cfg->{temporary_report_frequency} == 0)
		{
			print "[INFO]Writting temporary report.\n";
			&writeCurrentRowsToReportFile (
					"$output_cfg->{report_directory_path}/$output_cfg->{temporary_report_filename}",
					"Push Down Temporary Report [1 - $id]", @rows);
		}
	}
	
	
	######################################################################
	# STEP 6: Post testing operations.
	######################################################################
	
	print "[INFO]Writting final report.\n";
	&writeCurrentRowsToReportFile (
			"$output_cfg->{report_directory_path}/$output_cfg->{final_report_filename}",
			"Push Down Final Report", @rows);
	
	# Statistic Time (TODO)
}

sub debug
{
	print STDERR @_ if $debug_enabled;
}

sub prepareDB
{
	system ("db2start");
	system ("db2 connect to $db_cfg->{feddb_name}");
	
	my $list_tables_rlt = `db2 list tables`;
	
	unless ($list_tables_rlt =~ /EXPLAIN_INSTANCE/)
	{
		system "db2 \"call SYSPROC.SYSINSTALLOBJECTS ('EXPLAIN', 'C', NULL, '$db_cfg->{feddb_schema}')\"";
	}
}

sub pushDownTest
{
	my ($id, $func, $rows_ref, $function_list_size) = @_;
	
	######################################################################
	# Subroutine Argument Description |
	#---------------------------------+
	#
	#   $func->{name}                    : function schema and name.
	#   $func->{return_type}             : function return type.
	#   @{$func->{arg}}                  : function arguments type array.
	#   $func->{remote_function_name}    : function remote format.
	#   
	#   $func->{schema}                  : schema of the function.
	#   $func->{pure_name}               : function name (without schema)
	#   
	#   $func->{test_arg}                : the special data/column used for push down test.
	#   $func->{test_arg}{1}             : it starts with index "1".
	#   
	#   $func->{is_operator}             : function is an operator.
	#   $func->{is_relational_operator}  : function is a relational operator.
	#   
	#   $func->{is_aggregation_function} : function is an aggregation function.
	#
	######################################################################
	
	my $func_sig = sprintf "%s (%s)->%s", $func->{name}, join (",", @{$func->{arg}}), $func->{return_type};
	
	&debug ("$func_sig\n");
	
	printf "%-110s", $func_sig;
	
	
	######################################################################
	# STEP 1: Prepare function arguments.
	######################################################################
	my $pos = 0;
	my @func_args;
	
	for (@{$func->{arg}})
	{
		$pos++;
		
		unless (defined $func->{test_arg} && defined $func->{test_arg}{$pos})
		{
			push @func_args, &typeToData ($_);
		}
		else
		{
			push @func_args, $func->{test_arg}{$pos};
		}
	}
	
	
	######################################################################
	# STEP 2: Generate function expression.
	######################################################################
	my $func_exp;
	
	unless (defined $func->{is_operator} && $func->{is_operator} =~ /^Y(ES)?$/i)
	{
		# Function is a normal function.
		$func_exp = sprintf "%s(%s)", $func->{name}, join (",", @func_args);
	}
	else
	{
		# Function is an operator function.
		if (@func_args != 2)
		{
			print "[ERROR]The number of arguments of operator \"$func->{name}\" not equals to 2.\n";
			return;
		}
		$func_exp = sprintf "(%s %s %s)", $func_args[0], $func->{pure_name}, $func_args[1];
	}
	
	
	######################################################################
	# STEP 3: Initialize local variables
	######################################################################
	my ($status1, $msg1, $status2, $msg2) = ("untested", "", "untested", "");
	my $first_rlt;
	
	
	######################################################################
	# STEP 4: Test and validate (PHASE I: function between SELECT and FROM)
	######################################################################
	unless (defined $func->{is_relational_operator} && $func->{is_relational_operator} =~ /^Y(ES)?$/i)
	{
		my $sql1 = "select $func_exp from $db_cfg->{tb_name}"; # do not exchange the position of them.
		my $sql2 = "select $func_exp from $db_cfg->{nk_name}";
		
		my $rlt = &runAndAnalyzeSQLCmds ($sql1, $sql2);
		
		$status1 = $rlt->{status};
		$msg1 .= $rlt->{msg};
		
		if ($status1 eq "succeed")
		{
			$first_rlt = &trim (&getFirstLine ($rlt->{rlt}));
			$msg1 .= sprintf "First result for sql(1,2): %s<br />", $first_rlt;
			
			my $vep_rlt = &validateExplainedPlan ($id, 1, $sql2, $func);
			
			$status1 = $vep_rlt->{status};
			$msg1 .= $vep_rlt->{msg};
		}
	}
	
	
	######################################################################
	# STEP 5: Test and validate (PHASE II: function after WHERE)
	######################################################################
	#can get (untested, ignored, error, matched, unmatched)#
	unless (defined $func->{is_aggregation_function} && $func->{is_aggregation_function} =~ /^Y(ES)?$/i
			|| $status1 =~ /(:?ignored|error)/)
	{
		my $where_stat;
		
		if (defined $func->{is_relational_operator} && $func->{is_relational_operator} =~ /^Y(ES)?$/i)
		{
			$where_stat = $func_exp;
		}
		elsif ($status1 ne "untested")
		{
			if ($first_rlt eq "-") #returned NULL
			{
				$where_stat = "$func_exp is null";
			}
			else
			{
				$where_stat = "$func_exp = ". &wrapData ($func->{return_type}, $first_rlt);
			}
		}
		
		if (defined $where_stat)
		{
			my $sql3 = "select DOB from $db_cfg->{tb_name} where $where_stat"; # do not exchange the position of them.
			my $sql4 = "select DOB from $db_cfg->{nk_name} where $where_stat";
			
			my $rlt2 = &runAndAnalyzeSQLCmds ($sql3, $sql4);
			
			$status2 = $rlt2->{status};
			$msg2 .= $rlt2->{msg};
			
			if ($status2 eq "succeed")
			{
				$msg2 .= sprintf "First result for sql(3,4): %s<br />", &trim (&getFirstLine ($rlt2->{rlt}));
				
				my $vep_rlt2 = &validateExplainedPlan ($id, 2, $sql4, $func);
				
				$status2 = $vep_rlt2->{status};
				$msg2 .= $vep_rlt2->{msg};
			}
		}
	}
	
	
	######################################################################
	# STEP 6: Output result
	######################################################################
	push @{$rows_ref}, &createRow ($id, $func_sig, $status1, $msg1, $status2, $msg2);
	
	printf " [ %-9s | %-9s ] [%5.2f%%]\n", $status1, $status2, $id / $function_list_size * 100;
}


###################### FOR QUERY EXECUTION AND ANALYSIS ######################
sub runAndAnalyzeSQLCmds
{
	my ($sql1, $sql2) = @_;
	my $msg;
	
	my ($sql1_rlt, $sql2_rlt, $sql1_cod, $sql2_cod);
	
	my $had_redo = 0;
	{
		system ("db2 set passthru $db_cfg->{srv_name} 2>&1 >/dev/null"); ###print dots to show the progress.
		
		$msg .= "sql1: $sql1<br />";
		$sql1_rlt = `db2 \"$sql1\"`;
		
		system ("db2 set passthru reset 2>&1 >/dev/null");
		
		$msg .=  "sql2: $sql2<br />";
		$sql2_rlt = `db2 \"$sql2\"`;
		
		$sql1_cod = getSQLCode ($sql1_rlt);
		$sql2_cod = getSQLCode ($sql2_rlt);
		
		if ($sql1_cod != 0 || $sql2_cod != 0)
		{
			if ($sql1_cod == $sql2_cod && $sql1_cod > 0)
			{
				$msg .=   " [W] Warning occurred.<br />";
			}
			else
			{
				$msg .=   " [E] Error occurred.<br />"
			}
			
			$msg .= sprintf "sql1 (code/status): %s/%s<br />", $sql1_cod, getSQLStatus ($sql1_rlt);
			$msg .= sprintf "sql2 (code/status): %s/%s<br />", $sql2_cod, getSQLStatus ($sql2_rlt);
			$msg .= "SQL1 OUTPUT:<br />$sql1_rlt<br />SQL2 OUTPUT:<br />$sql2_rlt<br />";
		}
		
		if (!$had_redo && $sql1_cod == $sql2_cod && $sql1_cod == -1024) ## DB2 connection interrupted
		{
			$had_redo = 1;
			system ("db2start");
			system ("db2 connect to $db_cfg->{feddb_name}");
			$msg .= "DB2 connection has been interrputed, will connect to DB and try it once more.<br />";
			redo;
		}
	}
	
	if ($sql1_cod == $sql2_cod && $sql1_cod >= 0)
	{
		my $sql1_sel_rlt = getSelectResult ($sql1_rlt);
		my $sql2_sel_rlt = getSelectResult ($sql2_rlt);
		
		if ($sql1_sel_rlt ne $sql2_sel_rlt && selectResultNotEqual ($sql1_sel_rlt, $sql2_sel_rlt))
		{
			$msg .= " [E] Result not equal.<br />" ;
			$msg .= "SQL1 OUTPUT:<br />$sql1_rlt<br />SQL2 OUTPUT:<br />$sql2_rlt<br />";
		}
		else
		{
			return { status => "succeed", rlt => $sql1_sel_rlt, msg => $msg };
		}
	}
	
	if ((grep {$sql1_cod == $_} @ignore_sql_error_code_only_for_table) && $sql2_cod >= 0)
	{
		return { status => "succeed", rlt => getSelectResult ($sql2_rlt), msg => $msg };
	}
	
	if ((grep {$sql2_cod == $_} @ignore_sql_error_code_only_for_nickname) && $sql1_cod >= 0)
	{
		return { status => "succeed", rlt => getSelectResult ($sql1_rlt), msg => $msg };
	}
	
	if (grep {$sql1_cod == $_} @ignored_sql_error_codes_once_seen_table
			|| grep {$sql2_cod == $_} @ignored_sql_error_codes_once_seen_nickname
			|| $sql1_cod == $sql2_cod && grep {$sql1_cod == $_} @ignored_sql_error_codes_both)
	{
		return { status => "ignored", rlt => "", msg => $msg };
	}
	
	return { status => "error", rlt => "", msg => $msg };
}


######################## FOR VALIDATING EXPLAINED PLAN #######################
sub validateExplainedPlan
{
	my ($id, $phase, $sql, $func) = @_;
	my $msg;
	
	my $select_opt_stmt_sql = "select cast (STATEMENT_TEXT as VARCHAR (1024)) from EXPLAIN_STATEMENT where EXPLAIN_LEVEL='P' and EXPLAIN_TIME=(select MAX(EXPLAIN_TIME) from EXPLAIN_STATEMENT)";
	my $select_rem_stmt_sql = "select ARGUMENT_VALUE from EXPLAIN_ARGUMENT where ARGUMENT_TYPE='RMTQTXT' and EXPLAIN_TIME=(select MAX(EXPLAIN_TIME) from EXPLAIN_ARGUMENT)";
	
	
	######################################################################
	# STEP 1: Run explain plan sql, record db2exfmt plan if needed.
	######################################################################
	my $explain_plan_output = `db2 \"explain plan for $sql\"`;
	
	$msg .= "<br />";
	
	unless (getSQLCode ($explain_plan_output) >= 0)
	{
		$msg .= " [E] Explain plan error.<br />";
		$msg .= "EXPLAIN PLAN SQL OUTPUT:<br />$explain_plan_output<br />";
		return { status => "error", msg => $msg };
	}
	
	if ($test_cfg->{record_db2exfmt_plan})
	{
		my $plan_path = "$test_cfg->{db2exfmt_plan_directory_path}/plan$id-$phase.pln";
		my $db2exfmt_output = `db2exfmt -d $db_cfg->{feddb_name} -e $db_cfg->{feddb_schema} -1 -o $plan_path 2>&1`;
		if ($db2exfmt_output =~ /Output is in/)
		{
			$msg .= "<a href=\"$plan_path\">db2exfmt_plan</a><br />";
		}
		else
		{
			$msg .= " [E] Output db2exfmt plan error.<br />";
			$msg .= "db2exfmt OUTPUT:<br />$db2exfmt_output<br />";
		}
	}
	
	
	######################################################################
	# STEP 2: Get optimized statement.
	######################################################################
	my $select_opt_stmt_rlt = `db2 \"$select_opt_stmt_sql\"`;
	my $opt_stmt = &trim (&getFirstLine (&getSelectResult ($select_opt_stmt_rlt)));
	
	$msg .= "<br />";
	$msg .= "optimized_statement: $opt_stmt<br />";
	
	
	######################################################################
	# STEP 3: Check function elimination.
	######################################################################
	if ($test_cfg->{check_function_elimination})
	{
		my $local_func_pattern = $func->{pure_name};
		
		$local_func_pattern =~ s/([\/.()+*])/\\$1/g;
		
		unless (defined $func->{is_operator} && $func->{is_operator} =~ /^Y(ES)?$/i)
		{
			# Function is a normal function.
			$local_func_pattern .= "\\s*\\(\\s*.+?\\s*\\)";
		}
		else
		{
			# Function is an operator function.
			$local_func_pattern = "\\(\\s*.+?\\s*". $local_func_pattern. "\\s*.+?\\s*\\)";
		}
		
		$msg .= "local_function_regex_pattern: $local_func_pattern<br />";
		
		unless ($opt_stmt =~ /$local_func_pattern/i)
		{
			$msg .= "elimination_check_result: ELIMINATED<br /><br />";
##			return { status => "eliminated", msg => $msg }; ##maybe replaced or INTERNAL_FUNC
		}
	}
	
	
	######################################################################
	# STEP 4: Trace for $INTERNAL_FUNC$().
	######################################################################
	if ($test_cfg->{trace_for_internal_func} && $opt_stmt =~ /\$INTERNAL_FUNC\$\(\)/)
	{
		my $trace_path = "$test_cfg->{trace_directory_path}/eptrc$id-$phase.trc";
		my $trace_fmt_path = "$test_cfg->{trace_directory_path}/eptrc$id-$phase.fmt";
		
		`db2trc on -f $trace_path -m $test_cfg->{trace_for_internal_func_mask}`;
		`db2 \"explain plan for $sql\"`;
		`db2trc off`;
		`db2trc fmt $trace_path $trace_fmt_path`;
		`rm $trace_path`;
		
		my $trace_fmt_fh;
		my %internal_func_set;
		unless (open ($trace_fmt_fh, "<", $trace_fmt_path))
		{
			$msg .= " [E] Open trace file error: $!.<br />";
		}
		else
		{
			$msg .= "<a href=\"$trace_fmt_path\">db2trc_for_internal_func</a><br />";
			
			while (<$trace_fmt_fh>)
			{
				if (/^\s+(.+?) has no mapping by local signature\.$/)
				{
					$internal_func_set{$1} = 1;
				}
			}
			
			close $trace_fmt_fh;
			
			$msg .= "internal_functions: ". (join "<br />", keys %internal_func_set). "<br />";
		}
	}
	
	
	######################################################################
	# STEP 5: Get remote statements.
	######################################################################
	my $select_rem_stmt_rlt = `db2 \"$select_rem_stmt_sql\"`;
	my @rem_stmts = map { &trim ($_) } split (/\n/, &getSelectResult ($select_rem_stmt_rlt));
	
	$msg .= "remote_statements: ". (join "<br />", @rem_stmts). "<br />";
	
	
	######################################################################
	# STEP 6: Check function push down.
	######################################################################
	(my $remote_func_pattern = $func->{remote_function_name}) =~ s/([.()+*])/\\$1/g;
	$remote_func_pattern =~ s/\s+/\\s*/g;
	$remote_func_pattern =~ s/(:\d[PLRK]|:[DM]|:RA|:RB)/.+?/g;
	
	$msg .= "remote_function_name: $func->{remote_function_name}<br />";
	$msg .= "remote_function_regex_pattern: $remote_func_pattern<br />";
	
	if ((join " ", @rem_stmts) =~ /$remote_func_pattern/i)
	{
		$msg .= "push_down_result: MATCHED<br /><br />";
		return { status => "matched", msg => $msg };
	}
	else
	{
		$msg .= "push_down_result: NOT MATCHED<br /><br />";
		return { status => "unmatched", msg => $msg };
	}
}


#################### FOR TYPE CONVERSION AND DATA WRAPPING ###################
sub typeToData
{
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
	
	my ($type) = @_;
	
	return $type_data_mapping{$type} if defined $type_data_mapping{$type};
	return "[UNKNOWN]";
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


######################### FOR QUERY RESULT PROCESSING ########################
sub selectResultNotEqual
{
	my @sel_rlt1 = split "\n", shift;
	my @sel_rlt2 = split "\n", shift;
	
	return 1 if (@sel_rlt1 != @sel_rlt2);
	
	for (0..(@sel_rlt1 - 1))
	{
		return 1 if (&trim ($sel_rlt1[$_]) ne &trim ($sel_rlt2[$_]));
	}
	return 0;
}

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

sub getLines
{
	my $string = shift;
	return split /\n/, $string;
}

sub getSelectResult
{
	my ($output) = @_;
	my $ret = "";
	my $record_started = 0;
	my $record_just_began = 1;
	for (split /\n/, $output)
	{
		chomp;
		next if /^\s*$/;
		last if /record\(s\) selected\./ || /DB2(\d\d\d\d)([WN])/ || /SQL(\d\d\d\d)([WN])/;
		if ($record_started)
		{
			if ($record_just_began)
			{
				$record_just_began = 0;
				$ret .= "$_";
			}
			else
			{
				$ret .= "\n$_";
			}
		}
		$record_started = 1 if !$record_started && /^[-\s]+$/;
	}
	return $ret;
}

sub getCLPCode
{
	my ($output) = @_;
	if ($output =~ /DB2(\d{4,5})([WN])/)
	{
		return $1 if $2 eq "W";
		return "-$1" if $2 eq "N";
	}
	return 0;
}

sub getSQLCode
{
	my ($output) = @_;
	if ($output =~ /SQL(\d{4,5})([WN])/)
	{
		return $1 if $2 eq "W";
		return "-$1" if $2 eq "N";
	}
	return 0;
}

sub getSQLStatus
{
	my ($output) = @_;
	if ($output =~ /SQLSTATE=([0-9A-Z]+)/)
	{
		return $1;
	}
	return 0;
}


############################ FOR REPORT GENERATING ###########################
sub initReportTemplates
{
	open FH, "<", $output_cfg->{report_mainpage_template_path};
	$report_mainpage_template = do { local $/; <FH> };
	
	open FH, "<", $output_cfg->{report_table_template_path};
	$report_table_template = do { local $/; <FH> };
	
	open FH, "<", $output_cfg->{report_row_template_path};
	$report_row_template = do { local $/; <FH> };
	
	close FH;
}

sub createRow
{
	my ($id, $func_sig, $status1, $msg1, $status2, $msg2) = @_;
	
	my $row = $report_row_template;
	
	$msg1 =~ s/\n/<br \/>/g;
	$msg2 =~ s/\n/<br \/>/g;
	
	$row =~ s/\[\[ID\]\]/$id/g;
	$row =~ s/\[\[FUNC_SIG\]\]/$func_sig/g;
	$row =~ s/\[\[PHASE1_STATUS\]\]/$status1/g;
	$row =~ s/\[\[PHASE2_STATUS\]\]/$status2/g;
	$row =~ s/\[\[PHASE1_CONTENT\]\]/$msg1/g;
	$row =~ s/\[\[PHASE2_CONTENT\]\]/$msg2/g;
	
	return $row;
}

sub createTable
{
	my (@rows) = @_;
	
	my $table = $report_table_template;
	
	my $rows = join "\n", @rows;
	
	$table =~ s/\[\[ROWS\]\]/$rows/;
	
	return $table;
}

sub createReport
{
	my ($title, $content) = @_;
	
	my $mainpage = $report_mainpage_template;
	
	$mainpage =~ s/\[\[TITLE\]\]/$title/g;
	$mainpage =~ s/\[\[CONTENT\]\]/$content/;
	
	return $mainpage;
}

sub writeCurrentRowsToReportFile
{
	my ($reportFileName, $title, @rows) = @_;
	open my ($fh), ">", $reportFileName or do
	{
		print " [ERROR]Cannot open \"$reportFileName\": $!.\n";
		return;
	};
	print $fh &createReport ($title, &createTable (@rows));
	close $fh;
}


#################################### MAIN ####################################
&main;

exit 0;
