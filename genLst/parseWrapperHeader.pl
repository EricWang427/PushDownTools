#!/usr/bin/perl
use strict;
use warnings;

die "please input filename\n" unless @ARGV > 0;
die "only one file can be processed\n" unless @ARGV < 2;

my ($filename) = @ARGV;

die "cannot access file: $filename\n" unless -f $filename;

&parseSQLQG_DRDA_ATTRS_UDB_H ($filename);

sub parseSQLQG_DRDA_ATTRS_UDB_H
{
	my ($filename) = @_;
	
	open DRDA_FILE, "<", $filename or die;
	
	my $comment = 0;
	my $parse_started = 0;
	
	READ_DRDA_FILE: while (<DRDA_FILE>)
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
				next READ_DRDA_FILE unless m(\*/);
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
		$parse_started = 1 if !$parse_started && /static Default_Remote_Function/;
		
		if ($parse_started)
		{
			if (/\{  \(UCHAR \*\)\"(.+)\",/)
			{
				my $local_func = $1;
				
				chomp (my $nextline = readline DRDA_FILE);
				my ($remote_func) = ($nextline =~ /\(UCHAR \*\)\s*\"(.+)\",/);
				
				my ($local_func_schema, $local_func_name, $local_func_argvs) = ($local_func =~ /^(.+?)\.(.+?)(\(.*\))?$/);
				
				if (!defined $local_func_argvs)
				{
					$local_func_argvs = "";
				}
				else
				{
					$local_func_argvs =~ s/^\(//;
					$local_func_argvs =~ s/\)$//;
				}
				
				print "$local_func_schema;$local_func_name;$local_func_argvs;$remote_func\n";
			}
		}
	}
	close DRDA_FILE;
}
