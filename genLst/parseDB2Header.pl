#!/usr/bin/perl
use strict;
use warnings;

die "please input filename\n" unless @ARGV > 0;
die "only one file can be processed\n" unless @ARGV < 2;

my ($filename) = @ARGV;

die "cannot access file: $filename\n" unless -f $filename;

&parseSQLNN_FUN_FUN_H ($filename);

sub parseSQLNN_FUN_FUN_H
{
	my ($filename) = @_;
	
	open DB2_FILE, "<", $filename or die;
	
	my $comment = 0;
	my $parse_started = 0;
	
	my $parsing_func_name = 1;
	my $parsing_func_schema = 1;
	my $parsing_func_argvs = 1;
	my $parsing_func_ret = 1;
	
	my ($func_name, $func_schema, @func_argv, $func_ret);
	
	my $i = 0;
	
	READ_DB2_FILE: while (<DB2_FILE>)
	{
		# format adjust
		chomp;
		{
			unless ($comment)
			{
				s(/\*.*?\*/)()g;
				s(//.*$)();
			}
			if ($comment)
			{
				next READ_DB2_FILE unless m(\*/);
				$comment = 0;
				s(^.*?\*/)();
				redo;
			}
			if (!$comment && m(/\*))
			{
				$comment = 1;
				s(/\*.*$)();
			}
		}
		s/\s*$//;
		next if /^$/;
		
		# parsing
		$parse_started = 1 if !$parse_started && /extern SQLZ_DLLEXPORT/;
		
		if ($parse_started)
		{
			if ($parsing_func_name)
			{
				if (/\"(.+?)\"/)
				{
					$func_name = $1;
					s/\"(.+?)\"//;
					$parsing_func_name = 0;
				}
			}
			if (!$parsing_func_name && $parsing_func_schema)
			{
				if (/\"(.+?)\"/)
				{
					$func_schema = $1;
					s/\"(.+?)\"//;
					$parsing_func_schema = 0;
				}
			}
			if (!$parsing_func_name && !$parsing_func_schema && $parsing_func_argvs)
			{
				#push @func_argv, $1 if /\{\s*(SQLNQ_UNKNOWN|SQLZ_TYP_.+?|SQLRG_TYP_STRINGLEN_UNIT|SQLZ_NOTYP)\s*,/;
				push @func_argv, $1 if /\{\s*([0-9a-zA-Z_]+)\s*,/;
				
				$parsing_func_argvs = 0 if /NULLP,/;
			}
			if (!$parsing_func_name && !$parsing_func_schema && !$parsing_func_argvs && $parsing_func_ret)
			{
				#if (/\{\s*(SQLNQ_UNKNOWN|SQLZ_TYP_.+?|SQLRG_TYP_STRINGLEN_UNIT|SQLZ_NOTYP)\s*,/)
				if (/\{\s*([0-9a-zA-Z_]+)\s*,/)
				{
					$func_ret = $1;
					$parsing_func_ret = 0;
				}
			}
			if (!$parsing_func_name && !$parsing_func_schema && !$parsing_func_argvs && !$parsing_func_ret)
			{
				#printf "%4s: $func_ret $func_schema.$func_name(%s)\n", ++$i, join ",", @func_argv; #2158: SYSIBM.CU32_CAST_L_W
				printf "$func_schema;$func_name;$func_ret;%s\n", join ",", @func_argv; #2158: SYSIBM.CU32_CAST_L_W
				$parsing_func_name = 1;
				$parsing_func_schema = 1;
				$parsing_func_argvs = 1;
				$parsing_func_ret = 1;
				
				$func_name = undef;
				$func_schema = undef;
				@func_argv = ();
				$func_ret = undef;
			}
		}
	}
	close DB2_FILE;
}
