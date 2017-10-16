Set-StrictMode -Version 2
$errorActionPreference = 'Stop'

$scriptDir = Split-Path $psCommandPath

function test {
    param(
        [string] $name,
        [scriptblock]$sb
    )

    try {
        & $sb
    } catch {
        Write-Host -ForegroundColor Red "[$name] failed - $_"
        return
    }
    Write-Host -ForegroundColor Green "[$name] passed"
}

function ce {
    param(
        $expected,
        $actual
    )
    if(-not ($expected -eq $actual)){
        throw "Items were not equal. Expected [$expected] Actual [$actual]"
    }
}

function cae {
    param(
        [object[]] $expected,
        [object[]] $actual
    )

    if($expected.Length -ne $actual.Length){
        throw "Expected length $($expected.Length) does not match actual length $($actual.Length)"
    }
    for($i = 0; $i -lt $actual.length; $i++){
        ce $actual[$i] $expected[$i]
    }
}

Import-Module "$scriptDir/unishell.psm1" -force

# Get-UniCodepoint tests

test 'Get "X" codepoint' {
    $cp = Get-UniCodepoint 'X'
    ce 'X' $cp.Value
    ce 0x0058 $cp.Codepoint
    ce 'U+0058' $cp.CodepointString
    ce 'LATIN CAPITAL LETTER X' $cp.Name
    ce 'Basic Latin' $cp.Block
    ce '0 - Basic Multilingual Plane' $cp.Plane
    ce '1.1' $cp.UnicodeVersion
    ce 'Latin' $cp.Script
    ce 'AL - Alphabetic' $cp.LineBreakClass
    ce 'Lu - Letter, Uppercase' $cp.Category
    ce '0 - Spacing, split, enclosing, reordrant, and Tibetan subjoined' $cp.CanonicalCombiningClasses
    ce 'L - Left-to-Right' $cp.BidiCategory
    ce $false $cp.Mirrored
    ce 0x0078 $cp.LowercaseMapping
    cae @(0x58) $cp.'utf-8'
    cae @(0x58, 0x00) $cp.'utf-16'
    cae @(0x00, 0x58) $cp.'utf-16BE'
}

test 'Codepoint at unicodedata.txt range start' {
    $cp = Get-UniCodepoint 0x17000
    ce 0x17000 $cp.Codepoint
    ce 'Tangut Ideograph' $cp.Name
    ce '1 - Supplementary Multilingual Plane' $cp.Plane
}

test 'Codepoint at unicodedata.txt range end' {
    $cp = Get-UniCodepoint 0xFFFFD
    ce 0xFFFFD $cp.Codepoint
    ce 'Plane 15 Private Use' $cp.Name
    ce '15 - Supplementary Private Use Area-A' $cp.Plane
}

test 'Codepoint within unicodedata.txt range' {
    $cp = Get-UniCodepoint 0x21000
    ce 0x21000 $cp.Codepoint
    ce 'CJK Ideograph Extension B' $cp.Name
    ce '2 - Supplementary Ideographic Plane' $cp.Plane
}

test 'Unassigned codepoint' {
    $cp = Get-UniCodepoint 0x16E00
    ce 0x16E00 $cp.Codepoint
    ce 'Unassigned' $cp.Name
    ce 'Unassigned' $cp.Block
    ce '1 - Supplementary Multilingual Plane' $cp.Plane
    ce 'Unknown' $cp.Script
    ce 'XX - Unknown' $cp.LineBreakClass
    ce $null $cp.Category
    ce $null $cp.BidiCategory
    ce $null $cp.DecompositionMapping
    ce $null $cp.DecimalDigitValue
    ce $null $cp.DigitValue
    ce $null $cp.NumericValue
    ce $false $cp.Mirrored
    ce $null $cp.UppercaseMapping
    ce $null $cp.LowercaseMapping
    ce $null $cp.TitlecaseMapping
}

test 'Numeric codepoint' {
    $cp = Get-UniCodepoint 0x2181
    ce 0x2181 $cp.Codepoint
    ce 'ROMAN NUMERAL FIVE THOUSAND' $cp.Name
    ce "$([char]0x2181)" $cp.Value
    ce 5000 $cp.NumericValue
}

test 'Digit codepoint' {
    $cp = Get-UniCodepoint 0xA8D5
    ce 0xA8D5 $cp.Codepoint
    ce 'SAURASHTRA DIGIT FIVE' $cp.Name
    ce "$([char]0xA8D5)" $cp.Value
    ce 5 $cp.DecimalDigitValue
    ce 5 $cp.DigitValue
    ce 5 $cp.NumericValue
}

test "Isolated unpaired high surrogate" {
    $cp = Get-UniCodepoint 0xD801
    ce 0xD801 $cp.Codepoint
    ce "$([char]0xD801)" $cp.Value
    ce 'High Surrogates' $cp.Block
    ce 'Non Private Use High Surrogate' $cp.Name
    ce 'SG - Surrogate' $cp.LineBreakClass
    ce 'Cs - Other, Surrogate' $cp.Category
}

test "Interpolated unpaired high surrogate" {
    $cp = Get-UniCodepoint "A$([char]0xD801)B"
    ce 3 $cp.length
    ce 0x0041 $cp[0].Codepoint
    ce 0xd801 $cp[1].Codepoint
    ce 0x0042 $cp[2].Codepoint
}

test "Isolated unpaired low surrogate" {
    $cp = Get-UniCodepoint 0xDC01
    ce 0xDC01 $cp.Codepoint
    ce "$([char]0xDC01)" $cp.Value
    ce 'Low Surrogates' $cp.Block
    ce 'Low Surrogate' $cp.Name
    ce 'SG - Surrogate' $cp.LineBreakClass
    ce 'Cs - Other, Surrogate' $cp.Category
}

test "Interpolated unpaired low surrogate" {
    $cp = Get-UniCodepoint "A$([char]0xDC01)B"
    ce 3 $cp.length
    ce 0x0041 $cp[0].Codepoint
    ce 0xDC01 $cp[1].Codepoint
    ce 0x0042 $cp[2].Codepoint
}

test "Jumbled isolated surrogates" {
    $hi = [char]0xD802
    $lo = [char]0xDC02
    $cp = Get-UniCodepoint "$lo$lo $hi$hi $lo$hi"
    ce 8 $cp.length
    cae @(0xdc02,0xdc02,0x0020,0xd802,0xd802,0x0020,0xdc02,0xd802) $cp.Codepoint
}

test "module import can download data files" {
    $files = @('UnicodeData','DerivedAge','Blocks','Scripts','LineBreak')
    $files |%{  Remove-Item "$scriptDir/$_.txt" -ea 0 }

    Import-Module "$scriptDir/unishell.psm1" -force -ArgumentList ($scriptDir, @('utf-8'), $true)

    $files |%{ 
        if(-not (Test-path "$scriptDir/$_.txt")){
            throw "Expected to find file $_.txt downloaded"
        }
    }
}
