#!/bin/csh -f

# Simple script to generate the class documentation from the 
# pods in the correct format. Requires the pod2latex command
# found in perl 5.7.0 and above (Pod::LaTeX 
# written by Tim Jenness)

# When run, the relevant files are processed by pod2latex into
# a single output tex file which can either be inserted into
# sun233.tex directly or included. It will not be a complete
# document

# A very, very simple script

# output file name
set cwd = `pwd`
set output = "$cwd/sun233_classes.tex"

# List of files to process
set input = ""
foreach i ( Basic.pm Calib.pm Calib/SCUBA.pm Constants.pm Convert.pm Core.pm  Display.pm Display/Base.pm Display/GAIA.pm Display/KAPVIEW.pm Frame.pm Frame/NDF.pm Frame/UKIRT.pm Frame/JCMT.pm General.pm Group.pm Group/NDF.pm Group/UFTI.pm Group/JCMT.pm Index.pm LogFile.pm Loop.pm Msg/ADAM/Control.pm Msg/ADAM/Task.pm Print.pm TempFile.pm)
  echo $i
  set input = "$input ORAC/$i"
end


# Since the $input variable seems to run into buffer overflow if I prepend
# the path, overcome this by changing to the ORAC_PERL5LIB directory but
# specifying the output file name as a full path

cd $ORAC_PERL5LIB

# Run the command
set bindir = "/home/timj/perlmods/Pod/LaTeX/"
$bindir/pod2latex -out $output -modify -h1level 2 -sections "\!AUTHORS" $input

# Return to cwd

cd $cwd;
