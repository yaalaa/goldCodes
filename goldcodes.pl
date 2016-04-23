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
# Something about M-sequences and Gold codes, M=8
#

use strict;
use Getopt::Long;
use Scalar::Util qw(blessed reftype);
use Data::Dumper;
use File::Path qw(make_path);
use List::Util qw(min max);

$|=1;

local $/;

# hello message
printf "Hi there, I'm %s\n", $0;


# looks for m-sequences

my $regBitCnt = 8;
my $regValueMax = 2 << $regBitCnt - 1;
my $seqLenMax = 2 << $regBitCnt - 1;

printf "Register bit count : %s\n", $regBitCnt;
printf "Sequence max.length: %s\n", $seqLenMax;
printf "\n";

my %mSeqs;
my %mSeqsByStdName;

for ( my $idx = 1; $idx < $regValueMax; $idx++ )
{
    my $seq = buildMSeq( $idx );
    
    if ( !$seq ) # not an m-seq
    {
        next;
    }
    
    $mSeqs{ $idx } = $seq;
    $mSeqsByStdName{ $seq->{ "stdName" } } = $seq;
    
    printf "Found m-sequence: std: %- 28s %08b  autoCorr: %s\n", $seq->{ "stdName" }, $seq->{ "coeffInt" }, $seq->{ "autoCorr" }->{ "status" };
}

printf "\nFound %s m-sequences\n", scalar( keys %mSeqs );

# test { 8, 7, 6, 5, 2, 1 } { 8, 7, 6, 1 }
buildGoldSeq( "{ 8, 7, 6, 5, 2, 1 }", "{ 8, 7, 6, 1 }", \%mSeqsByStdName );

printf "\n.Done.\n";
exit( 0 );


sub buildGoldSeq()
{
    my $seqAStdName = shift @_;
    my $seqBStdName = shift @_;
    my $mSeqs = shift @_;
    
    {{
        my $seqA = $mSeqs->{ $seqAStdName };
        
        if ( !$seqA ) # no A sequence
        {
            printf "Sequence %s not found\n", $seqAStdName;
            last;
        }
        
        my $seqB = $mSeqs->{ $seqBStdName };
        
        if ( !$seqB ) # no B sequence
        {
            printf "Sequence %s not found\n", $seqBStdName;
            last;
        }
    
        my $srcCorr = calcCorrelation( $seqA->{ "values" }, $seqB->{ "values" } );
        
        printf "Gold from %s %s | corr: %s\n", $seqAStdName, $seqBStdName, $srcCorr->{ "status" };
        
        my $valuesA = $seqA->{ "values" };
        my $valuesB = $seqB->{ "values" };
        
        if ( length( $valuesA ) <= 0 || length( $valuesA ) != length( $valuesB ) ) # invalid values
        {
            printf "Sequence lengths do not match(%s != %s)\n", length( $valuesA ), length( $valuesB );
            last;
        }
        
        my $cnt = length( $valuesA );

        for ( my $idx = 0; $idx < $cnt; $idx++ )
        {
            my $cur = "";
            
            for ( my $t = 0; $t < $cnt; $t++ )
            {
                $cur .= ( ( substr( $valuesA, $t, 1 ) ? 1 : 0 ) + ( substr( $valuesB, ( $t + $idx ) % $cnt, 1 ) ? 1 : 0 ) ) % 2 ? "1" : "0";
            }
            
            printf "  ofs:%03d | %s\n", $idx, $cur;
        }
    }}
}


sub buildMSeq()
{
    my $coeffInt = shift @_;
    
    my $out;
    
    {{
        #printf "Testing coeffs: %08b", $coeffInt;
    
        my %data;
        
        $data{ "coeffInt" } = $coeffInt;

        my @stdNameBits;
        for ( my $idx = 0; $idx < $regBitCnt; $idx++ )
        {
            if ( ( $coeffInt >> $idx ) & 0x1 ) 
            {
                push( @stdNameBits, $regBitCnt - $idx );
            }
        }
        
        $data{ "stdName" } = "{ ".join( ", ",  @stdNameBits )." }";
        
        my $values = "";
        
        my @coeffs;
        my @state;
        
        for ( my $idx = 0; $idx < $regBitCnt; $idx++ )
        {
            push( @coeffs, ( ( $coeffInt >> $idx ) & 0x1 ) != 0 ? 1 : 0 );
            push( @state, $idx == 0 ? 1 : 0 );
        }
        
        my %test;
        
        $test{ 1 } = 1;
        my $len = 1;
        
        while ( 1 )
        {
            # next value
            my $acc = 0;
            for ( my $idx = 0; $idx < $regBitCnt; $idx++ )
            {
                $acc += $coeffs[ $idx ] * $state[ $idx ];
            }
            
            $acc = $acc % 2;
            
            $values .= $acc != 0 ? "1" : "0";
            
            # next state
            for ( my $idx = 1; $idx < $regBitCnt; $idx++ )
            {
                $state[ $idx - 1 ] = $state[ $idx ];
            }
            
            $state[ $regBitCnt - 1 ] = $acc;
            
            my $stateInt = 0;
            for ( my $idx = 0; $idx < $regBitCnt; $idx++ )
            {
                $stateInt += $state[ $idx ] * ( 2 << $idx );
            }
            
            if ( !$stateInt ) # zero state reached
            {
                $len = 0;
                last;
            }
            
            if ( $test{ $stateInt } ) # cycle
            {
                last;
            }
            
            $test{ $stateInt } = 1;
            $len++;
        }
        
        #printf "    len:%s    values:%s\n", $len, $values;
        
        if ( $len < $seqLenMax ) # not m-sequence
        {
            last;
        }
        
        $data{ "values" } = $values;
        $data{ "autoCorr" } = calcCorrelation( $values );
        
        $out = \%data;
    }}
    
    return $out;
}

sub calcCorrelation()
{
    my $valuesA = shift @_;
    my $valuesB = shift @_;
    
    if ( !$valuesB )
    {
        $valuesB = $valuesA;
    }
    
    my $out;
    
    {{
        if ( length( $valuesA ) <= 0 || length( $valuesA ) != length( $valuesB ) ) # invalid values
        {
            last;
        }
        
        my $cnt = length( $valuesA );
        
        my @values;
        
        for ( my $tau = 0; $tau < $cnt; $tau++ )
        {
            my $acc = 0;
        
            for ( my $t = 0; $t < $cnt; $t++ )
            {
                $acc += ( substr( $valuesA, $t, 1 ) ? 1 : 0 ) * ( substr( $valuesB, ( $t + $tau ) % $cnt, 1 ) ? 1 : 0 );
            }
            
            $acc /= $cnt;
            
            push( @values, $acc );
        }
        
        my %data;
        
        $data{ "values" } = \@values;
        $data{ "max" } = max( @values );
        
        my $status = sprintf( "max:%.4f", $data{ "max" } );
        
        if ( $cnt >= 7 )
        {
            $status .= sprintf( " | %.2f %.2f %.2f %.2f %.2f %.2f %.2f", $values[ $cnt - 3 ], $values[ $cnt - 2 ], $values[ $cnt - 1 ], $values[ 0 ], $values[ 1 ], $values[ 2 ], $values[ 3 ] );
        }
        
        $data{ "status" } = $status;
        
        $out = \%data;
    }}
    
    return $out;
}


my $usage = <<EOT;
Generates Xcode assets folders for animation frames

Usage:
  <me> [option ..]
  
  Options:
    --help              - this help screen
    --m-seq             - 
    --out-name <name>   - output assets basename
    --out-scale <scale> - output assets scale (defaults to 2)
    --in-regex          - input PNGs filename regex
                          should contain (\\d+) 
                          should match the whole filename (defaults to \\D*(\\d+).*\\.png)
    --in-dir <path>     - input directory (defaults to .)
    --out-dir <path>    - output directory (defaults to assets)

EOT


if ( scalar( @ARGV ) <= 0 ) # no arguments
{
    printf $usage;
    exit( 0 );
}

my $printHelp;
my $optOutName;
my $optOutScale = 2;
my $optInRegex = "\\D*(\\d+).*\\.png";
my $optInDir = ".";
my $optOutDir = "assets";

my $optResult = GetOptions( 
    "help"          => \$printHelp,
    "out-name=s"    => \$optOutName,
    "out-scale=i"   => \$optOutScale,
    "in-regex=s"    => \$optInRegex,
    "in-dir=s"      => \$optInDir,
    "out-dir=s"     => \$optOutDir,
    );

if ( !$optResult || $printHelp )
{
    printf $usage;
    exit( 0 );
}

# check output scale
if ( $optOutScale != 1 && $optOutScale != 2 && $optOutScale != 3 )
{
    printf "Error: invalid output scale[%s]\n", $optOutScale;
    exit( 1 );
}

# check input regex
if ( !( $optInRegex =~ /\(\\d\+\)/i ) )
{
    printf "Error: invalid input regex[%s]\n", $optInRegex;
    exit( 1 );
}

my $inRegex = $optInRegex;

$inRegex =~ s/^([^^])/^$1/;
$inRegex =~ s/([^\$])$/$1\$/;

# check input directory
my $inDir = ToStraightSlash( $optInDir );

if ( $inDir eq "/" )
{
    printf "Error: invalid input directory[%s]\n", $optInDir;
    exit( 1 );
}

# remove trailing slash
$inDir =~ s/\/$//;

if ( ! -d $inDir )
{
  printf "Error: input directory doesn't exist[%s]\n", $optInDir;
  exit( 1 );
}

# check input directory
my $outDir = ToStraightSlash( $optOutDir );

if ( $outDir eq "/" )
{
    printf "Error: invalid output directory[%s]\n", $optOutDir;
    exit( 1 );
}

# remove trailing slash
$outDir =~ s/\/$//;

if ( -d $outDir )
{
    printf "Error: output directory already exists[%s]\n", $optOutDir;
    exit( 1 );
}

# dump operation parameters
printf "Input directory : %s\n", $optInDir;
printf "Input regex     : %s -> %s\n", $optInRegex, $inRegex;
printf "Output directory: %s\n", $optOutDir;
printf "Output name     : %s\n", $optOutName;
printf "Output scale    : %s\n", $optOutScale;
    
# prepare contents

my $contentsGeneric = "\n      \"filename\" : \"\%s\",";
my $contents1x = $optOutScale == 1 ? $contentsGeneric : "";
my $contents2x = $optOutScale == 2 ? $contentsGeneric : "";
my $contents3x = $optOutScale == 3 ? $contentsGeneric : "";


my $contents = <<EOT;
{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x",$contents1x
    },
    {
      "idiom" : "universal",$contents2x
      "scale" : "2x"
    },
    {
      "idiom" : "universal",$contents3x
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}

EOT

my $outFileNameFmt = $optOutName."%d\@${optOutScale}x.png";

# look for input files
my %pngs;

{
    my $dirH;

    if ( !opendir( $dirH, $inDir ) )
    {
        printf "Error: opendir[%s] failed [%s]\n", $optInDir, $!;
        exit( 1 );
    }

    my @files = grep( /$inRegex/i, readdir( $dirH ) );

    closedir( $dirH );
    
    if ( scalar( @files ) <= 0 )
    {
        printf "Error: no input file found in [%s]\n", $optInDir, $!;
        exit( 1 );
    }
    
    for my $cur ( @files )
    {
        if ( $cur =~ /$inRegex/i )
        {
            my $ofs = $1;
    printf "matches[%s]: %s -> %s\n", $inRegex, $cur, $ofs;
            $pngs{$ofs} = $cur;
        }
    }
}

# write output
{
    my $ok = 1;
    my $ofs = 0;

    for my $idx ( sort { $a <=> $b } keys %pngs )
    {
        my $curName = "${optOutName}${ofs}";
        my $curPath = "${outDir}/${curName}.imageset";
        
        my $outPngName = sprintf( $outFileNameFmt, $ofs );
        
        make_path( $curPath );
        
        {
            my $contentsName = "${curPath}/Contents.json";
            
            my $h;
            
            if ( !open( $h, ">$contentsName" ) )
            {
                printf "Error: open[%s] failed [%s]\n", $contentsName, $!;
                $ok = 0;
                last;
            }

            printf $h $contents, $outPngName;

            close( $h );
        }
        
        link( "$inDir/".$pngs{$idx}, "${curPath}/${outPngName}" );
        
        $ofs++;
    }
    
    if ( ! $ok )
    {
        exit( 1 );
    }
    
    printf "Assets written  : %s\n", $ofs;
}


printf "\n.Done.\n";
exit( 0 );

sub TrimStr
{
  my $str = shift( @_ );
  
  $str =~ s/^\s+([^\s].*)$/$1/g;
  $str =~ s/^(.*[^\s])\s+$/$1/g;
  
  return $str;
}

sub ToStraightSlash
{
  my $src = shift( @_ );
  
  $src =~ s/\\/\//g;
  
  return $src;
}
