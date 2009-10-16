package ORAC::Recipe::Parameters;

=head1 NAME

ORAC::Recipe::Parameters - Handle recipe parameters

=head1 SYNOPSIS

  use ORAC::Recipe::Parameters;

  $par = ORAC::Recipe::Parameters->new( $file );
  %params = $par->for_recipe( $recipe );

=head1 DESCRIPTION

Handle the parsing and retrieval of recipe parameters for ORAC-DR
recipes.

=cut

use strict;
use warnings;
use vars qw/ $VERSION $DEBUG /;
use Carp;

use Data::Dumper;
use Config::IniFiles;
use File::Spec;

$DEBUG = 0;
$VERSION = '0.1';

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Create a new parameter object using the supplied file name as a source
of parameters. The file can be a fully specified path or else will assumed
to be found in the current directory, ORAC_DATA_OUT or ORAC_DATA_CAL.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $file = shift;
  return undef unless defined $file;

  my $obj = bless {
                   File => undef,
                   Parameters => {},
                  }, $class;

  my $path = $obj->_locate_file( $file );
  print "PATH = ". (defined $path ? $path : "<undef>")."\n" if $DEBUG;
  return undef unless defined $path;

  # update filename and parse it
  $obj->filename( $path );

  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of the file containing the recipe parameters specification.

 $f = $par->filename();

The file will be parsed automatically and the object updated if
a value is set.

 $par->filename( $file );

=cut

sub filename {
  my $self = shift;
  if (@_) {
    $self->{File} = shift;
    $self->_parse_file;
  }
  return $self->{File};
}

=item B<for_recipe>

Retrieves the parameters associated with a particular recipe.

 %params = $par->for_recipe( $recipe );

Will return an empty list if no parameters exist for the recipe
or if the recipe name is not defined.

=cut

sub for_recipe {
  my $self = shift;
  my $rec = shift;
  return () unless defined $rec;
  $rec = uc($rec);
  my %allpars = $self->_parameters();

  if (exists $allpars{$rec}) {
    return %{$allpars{$rec}};
  }
  return ();
}


=back

=begin __INTERNALS__

=head2 Internal Methods

=over 4

=item B<_parameters>

Parameters read from file, indexed by recipe name. Internal
routine to hide implementation.

  $par->_parameters( %config );
  %config = $par->_parameter();

Use C<for_recipe> method to retrieve the parameters for a particular
recipe.

=cut

sub _parameters {
  my $self = shift;
  if (@_) {
    %{$self->{Parameters}} = @_;
  }
  return %{$self->{Parameters}};
}


=item B<_locate_file>

Find the specified file and return the full path.
Looks in cwd, ORAC_DATA_OUT and ORAC_DATA_CAL in that
order, unless it's a fully-specified path.

 $path = $self->_locate_file( $file );

Returns undef if the file does not exist.

=cut

sub _locate_file {
  my $self = shift;
  my $file = shift;

  return undef unless defined $file;

  # fully specified path and file exists. Great.
  if (File::Spec->file_name_is_absolute($file)) {
    print "ABSOLUTE FILENAME: $file\n";
    return (-e $file ? $file : undef);
  }

  # Start looking around
  for my $dir ( File::Spec->curdir, $ENV{ORAC_DATA_OUT},
                $ENV{ORAC_DATA_CAL} ) {
    my $path = File::Spec->catfile( $dir, $file );
    if ( -e $path) {
      return File::Spec->rel2abs($path);
    }
  }
  return;
}

=item B<_parse_file>

Read the contents from the file and store it in the object.

=cut

sub _parse_file {
  my $self = shift;
  my $file = $self->filename;

  # Just get it straight into a hash
  my %data;
  tie %data, "Config::IniFiles", ( -file => $file, -nocase => 1 );
  print "Recipe parameters: ". Dumper(\%data) if $DEBUG;

  # Now we want to loop through the contents converting
  # keys to a fixed case, expanding comma separated lists
  # into array references.
  my %cfg;
  for my $key ( keys %data ) {
    print "Trying primary key '$key'\n" if $DEBUG;
    if (exists $data{$key} && defined $data{$key}) {

      # Want to lower case all the keys and process arrays
      my %new;
      for my $oldkey (keys %{$data{$key}}) {
        my ($newkey, $newval) = $self->_clean_entry($oldkey, $data{$key}->{$oldkey});
        $new{$newkey} = $newval;
      }

      # Store the keys in the config, indexed by recipe
      $cfg{uc($key)} = \%new;
    }
  }

  print "Parsed parameters: ". Dumper(\%cfg) if $DEBUG;

  $self->_parameters( %cfg );

}

=item B<_clean_entry>

Clean up an entry in the config hash. Will upper case keys and convert
comma-separated entries into arrays references.

 ($newkey, $newval) = $cfg->_clean_entry( $oldkey, $oldval );

=cut

sub _clean_entry {
  my $self = shift;
  my $oldkey = shift;
  my $oldval = shift;

  my $newkey = uc($oldkey);
  my $newval = $oldval;

  if (!ref($newval) && $newval =~ /,/) {
    $newval = [ split(/\s*,\s*/,$newval)];
  } elsif (ref($newval) eq 'HASH') {
    # Nested. Need to recurse
    my %nest;
    for my $nestkey (keys %$newval) {
      my ($new_nestkey, $new_nestval) = $self->_clean_entry( $nestkey,
                                                              $newval->{$nestkey} );
      $nest{$new_nestkey} = $new_nestval;
    }
    $newval = \%nest;
  }

  return ($newkey, $newval);
}

=back

=end __INTERNALS__

=head1 FILE FORMAT

The recipe parameters file uses standard "INI" format comprising of sections
containing keyword=value pairs.

 [RECIPE_NAME]
 param1 = value1
 param2 = array1,array2,array3
 param3 = string

 [RECIPE2_NAME]
 param1 = value

Comma-separated values are converted to perl arrays. Multiple recipes
can be specified in a single parameter file.

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;