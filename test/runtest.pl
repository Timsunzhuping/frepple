#!/usr/bin/perl
#  file     : $HeadURL$
#  revision : $LastChangedRevision$  $LastChangedBy$
#  date     : $LastChangedDate$
#  email    : jdetaeye@users.sourceforge.net

#
# This simple perl script provides a simplistic framework for executing unit
# tests.
# Each test has its own subdirectory. In the description below it is referred
# to as {testdir}.
# Three categories of tests are supported.
#
#  - Type 1: Compiled executable
#    If an executable file {testdir} or {testdir}.exe is found in the test
#    directory, the executable is run. The compilation/generation of the
#    executable is not handled by the script, but it's typically done by
#    running the command "make check" in the test subdirectory.
#    The test is successful if both:
#      1) the exit code of the program is 0
#      2) the output of the program is identical to the content of the
#         file {testdir}.expect
#
#  - Type 2: Run a Perl test script
#    If a file runtest.pl is found in the test directory, it is being run
#    and its exit code is used as the criterium for a successful test.
#
#  - Type 3: Process an XML file
#    If a file {testdir}.xml is found in the test directory, the frepple
#    commandline executable is called to process the file.
#    The test is successful if both:
#      1) the exit code of the program is 0
#      2) the generated output files of the program match the content of the
#         files {testdir}.{nr}.expect
#    If a file init.xml is found in the test directory, the test directory
#    is used as the frepple home directory.
#
#  - If the test subdirectory doesn't match the criteria of any of the above
#    types, the directory is considered not to contain a test.
#
# The script can be run with the following arguments on the command line:
#  - ./runtest.pl {test}
#    ./runtest.pl {test1} {test2}
#    Execute the tests listed on the command line.
#  - ./runtest.pl
#    Execute all tests.
#  - ./runtest.pl -vcc
#    Execute all tests using the executables compiled with Microsofts'
#    Visual Studio C++ compiler.
#    Tests of type 1 are skipped in this case.
#  - ./runtest.pl -bcc
#    Execute all tests using the executables compiled with the Borland
#    C++ compiler.
#    Tests of type 1 are skipped in this case.
#

use strict;
no strict 'refs';
use warnings;

use Cwd 'abs_path';
use Env qw(EXECUTABLE FREPPLE_HOME LD_LIBRARY_PATH LIBPATH SHLIB_PATH);

# Set the variable FREPPLE_HOME
$FREPPLE_HOME = abs_path("../bin") if (!$FREPPLE_HOME);

# Update the search path for shared libraries, such that the modules
# can be picked up. 
$LD_LIBRARY_PATH = "$FREPPLE_HOME:$LD_LIBRARY_PATH"; # Linux, Solaris
$LIBPATH = "$FREPPLE_HOME:$LIBPATH";  # AIX
$SHLIB_PATH = "$FREPPLE_HOME:$SHLIB_PATH";  # HPUX

# Executable to be used for the tests. Exported as an environment variable.
# This default executable is the one valid  for GCC cygwin and GCC *nux builds.
$EXECUTABLE = "../../libtool --mode=execute ../../src/frepple";
my $platform = "GCC";

# Put command line arguments in a hash, rather than keeping in an array
my %tests;
while (@ARGV) {
	my $opt = shift @ARGV;
	if ($opt eq "-vcc") {
		$platform = "VCC";
		$EXECUTABLE = "../../bin/frepple_vcc.exe";  # Generated by Visual C++
	} elsif ($opt eq "-bcc") {
		$platform = "BCC";
		$EXECUTABLE = "../../bin/frepple_bcc.exe";  # Generated by Borland C++
	} else {
		$tests{$opt} = 1;
	}
}

# Loop through all subdirectories
my $subdir;
my $tests = 0;
my @success;
my @failed;
my @aborted;
opendir(DIR, ".") || die "Error: Can't open current directory\n";
foreach (sort readdir DIR)
{
  $subdir = $_;

	# Skip files and dirs that are not tests...
	next if !(-d $subdir && $subdir ne "." && $subdir ne "..");

	# Skip if a set of test was given on the command line and the current
	# directory isn't one of them...
	next if %tests && !exists $tests{$subdir};

	# Determine type of test.
	my $type = 0;
	if (-x "$subdir/$subdir" || -x "$subdir/$subdir.exe") {
		# Type 1: (compiled) executable
		$type = 1;
		# This type of test isn't valid for Visual C++ and Borland builds
		next if $platform ne "GCC";
	} elsif (-r "$subdir/runtest.pl"){
		# Type 2: perl script runtest.pl available
		$type = 2;
	} elsif (-r "$subdir/$subdir.xml") {
		# Type 3: input xml file specified
		$type = 3;
	} else {
		# Undetermined - not a test directory
	  print "Skipping directory $subdir\n" if $subdir ne "CVS";
	  next;
	}

	# Run the test
	++$tests;
	print "\nRunning test $tests: '$subdir' (type $type) ...\n\n";
	chdir "$subdir";
	&{"test_type_$type"};
	if ($? ne 0)
	{
	  # Exit code of the program hints at an error
	  # The test was likely aborted by ctrl-C or other signals, crashed or aborted
		print "\nFinished test $tests: '$subdir'  FAILED \n\n";
		push @failed, $subdir;
	}
	else
	{
	  # Exit code of the program shows successful termination
		print "\nFinished test $tests: '$subdir'  OK\n\n";
		push @success, $subdir;
	}
	chdir "..";
}
closedir DIR;

# Print the final results
print "\nResults:\n";
print "  Total of $tests tests\n";
print "  " . ($#success+1) . " tests successful:\n";
for my $s (@success) {print "     $s\n";}
print "  " . ($#failed+1) . " tests failed:\n";
for my $f (@failed) {print "     $f\n";}

# Exit with the right exit code
die "\nTest failed...\n" if @failed;
print "\nTest passed\n";
exit;


sub test_type_1
{
  # Run the program
  system "./$subdir >test.out 2>&1";

  # Planning failed or was aborted
  return if $? ne 0;

  # Now check the output file, if there is an expected output given
	if (-r "test.out" && -r "$subdir.expect")
  {
	  print "\nComparing expected and actual output\n";
    system("diff -w $subdir.expect test.out ");
  }
}


sub test_type_2
{
  # Run the perl script
  system "./runtest.pl";
}


sub test_type_3
{
  # Delete previous output
  unlink glob("output.*.xml"), glob("output.*.txt"), glob("output.*.tmp");

  # Feed the input file to the planner application.
  # This type of test enforces validation of the input data.
  # A new frepple home directory is specified when a file init.xml exists in
  # test subdirectory
  my $oldhome = $FREPPLE_HOME;
  if (-r "init.xml") { $FREPPLE_HOME .= "/../test/$subdir"; }
  system "$EXECUTABLE -validate $subdir.xml";
	$FREPPLE_HOME = $oldhome;

  # Planning failed or was aborted
  return if $? ne 0;

  # Now check the output file, if there is an expected output given
  # The exit code of the system command is used as the test result
  my $nr = 1;
  print "\n";
  while (-r "$subdir.${nr}.expect" || -r "$subdir.${nr}s.expect")
  {
    if (-r "output.${nr}s.xml")
    {
      print "Summarizing the plan $nr\n";  # @todo shouldnt require unix statements any more
      system("grep -v OPERATION output.${nr}s.xml >output.${nr}s.tmp");
      system("grep OPERATION output.${nr}s.xml | sort >>output.${nr}s.tmp");
      system("grep -v PROBLEM output.${nr}s.tmp >output.${nr}s.txt");
      system("grep PROBLEM output.${nr}s.tmp >>output.${nr}s.txt");
      print "Comparing expected and actual output $nr\n";
      system("diff -w $subdir.${nr}s.expect output.${nr}s.txt");
      return if $? ne 0;
    }
    elsif (-r "output.${nr}.xml")
    {
      print "Comparing expected and actual output $nr\n";
      system("diff -w $subdir.${nr}.expect output.${nr}.xml");
      return if $? ne 0;
    }
    else
    {
      print "\nMissing planner output file\n";
      $? = 256;
    }
    ++$nr;
  }
}
