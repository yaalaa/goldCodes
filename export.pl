#!/usr/bin/perl

#
# The MIT License (MIT)
#
# Copyright (c) 2016 yaalaa
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Exports goldcodes to single script
#

BEGIN
{
    use File::stat;
    use File::Spec::Functions qw(rel2abs);
    use File::Basename;
}


use strict;


my $dependencies = <<'EOT';

#
# The MIT License (MIT)
#
# Copyright (c) 2016 yaalaa
#
# This file was generated by fatpack (https://metacpan.org/pod/fatpack)
# plus some additional magic steps.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

BEGIN
{
    my $requiredModules = [
        "Data::Dumper",
    ];
    
    for my $curModule ( @{ $requiredModules } )
    {
        #printf "Checking module $curModule";
        
        if ( !eval "require $curModule; 1" )
        {
            printf "\nModule $curModule is required.\n\n";
            
            if ( $^O eq "darwin" || $^O =~ /^linux/ )
            {
                printf "You likely to run:\ncpan -i $curModule\n\n";
            }
            
            exit( -1 );
        }
        
        #printf "  - OK\n";
    }
}
##########################################################################

EOT

my $srcScript = "goldcodes.pl";
my $packedScript = "goldcodes.packed.pl";
my $dstScript = "goldcodes.exported.pl";

unlink( $packedScript );
unlink( $dstScript );

if ( system( "fatpack pack $srcScript >$packedScript" ) != 0 )
{
    printf "Error: fatpack pack failed.\n";
    exit( 1 );
};

my $packedFile;
my $dstFile;

if ( !open( $packedFile, "<:encoding(UTF-8)", $packedScript ) ) # failed
{
    printf "open[%s] failed: %s \n", $packedScript, $!;
    exit( 1 );
}

if ( !open( $dstFile, ">:raw:encoding(UTF-8)", $dstScript ) ) # failed
{
    printf "open[%s] failed: %s \n", $dstScript, $!;
    exit( 1 );
}

my $depInserted = 0;

while ( <$packedFile> )
{
    my $ok = print $dstFile $_;
    
    if ( !$ok )
    {
        printf "print failed\n";
        exit( 1 );
    }
    
    if ( !$depInserted ) 
    {
        $ok = print $dstFile $dependencies;
    
        if ( !$ok )
        {
            printf "print failed\n";
            exit( 1 );
        }
        
        $depInserted = 1;
    }
}

close( $packedFile );
close( $dstFile );
