using namespace System.Collections.Generic

param(
    $dataFilesDirectory,
    $UnicodeVersion = '15.0.0'
)

Set-StrictMode -Version Latest

$scriptDir = Split-Path $psCommandPath
. $scriptDir/tables.ps1

# source data files
$unicodeDataPath = "$dataFilesDirectory/UnicodeData.txt"
$nerdFontDataPath = "$dataFilesDirectory/NerdFontData.txt"
$derivedAgePath = "$dataFilesDirectory/DerivedAge.txt"
$blocksPath = "$dataFilesDirectory/Blocks.txt"
$scriptsPath = "$dataFilesDirectory/Scripts.txt"
$lineBreakPath = "$dataFilesDirectory/LineBreak.txt"

$missingFiles = @()
if (-not (Test-Path $unicodeDataPath)) { $missingFiles += 'UnicodeData.txt' }
if (-not (Test-Path $nerdFontDataPath)) { $missingFiles += 'NerdFontData.txt' }
if (-not (Test-Path $derivedAgePath)) { $missingFiles += 'DerivedAge.txt' }
if (-not (Test-Path $blocksPath)) { $missingFiles += 'Blocks.txt' }
if (-not (Test-Path $scriptsPath )) { $missingFiles += 'Scripts.txt' }
if (-not (Test-Path $lineBreakPath)) { $missingFiles += 'LineBreak.txt' }

if ($missingFiles.Length -ne 0) {
    $errorMessage = "Required Unicode data files ($($missingFiles -join ', ')) were not found."
    Write-Host $errorMessage -ForegroundColor Yellow
    if ($AutoDownloadDataFiles -or ((Read-Host 'Press Y to download these files now') -match 'y')) {
        $missingFiles | % {
            Invoke-WebRequest "https://www.unicode.org/Public/${UnicodeVersion}/ucd/$_" -OutFile "$dataFilesDirectory/$_"
        }
    }
    else {
        Write-Error $errorMessage
        exit 1
    }
}

# all encodings supported by the running .NET framework
$allEncodings = [System.Text.Encoding]::GetEncodings().GetEncoding()
$allEncodingMap = @{};
$allEncodings | ForEach-Object { $allEncodingMap[$_.WebName] = $_ }

function resolveEncodings {
    [CmdletBinding()]
    [OutputType([System.Text.Encoding[]])]
    param
    (
        [ValidateNotNullOrEmpty()]
        [string[]] $Encoding
    )

    $Encoding | ForEach-Object {
        # Do a direct name lookup first
        if ($result = $allEncodingMap[$_]) {
            return $result
        }

        # Try parsing as the FileSystemCmdletProviderEncoding enum.
        # If $PSDefaultParameterValues contains a default for the Encoding parameter, it may contain one of these, and these don't neatly map to WebName.
        # @see https://stackoverflow.com/a/40098904/17152
        # @see https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.filesystemcmdletproviderencoding
        switch ($_) {
            'Unknown' {
                # Unknown: should not map
                throw "The encoding '$_' is not supported."
            }
            'String' {
                # 'String' is described by Microsoft as "Unicode encoding", which is how they describe 'Unicode'.
                return [System.Text.Encoding]::Unicode
            }
            'Unicode' {
                return [System.Text.Encoding]::Unicode
            }
            'Byte' {
                # Byte: Seems to be a special value to return a byte array instead of a string.  Not sure the right course of action here.
                throw "The encoding '$_' is not supported."
            }
            'BigEndianUnicode' {
                return [System.Text.Encoding]::BigEndianUnicode
            }
            'UTF8' {
                return [System.Text.Encoding]::UTF8
            }
            'UTF7' {
                return [System.Text.Encoding]::UTF7
            }
            'UTF32' {
                return [System.Text.Encoding]::UTF32
            }
            'UTF16' {
                # NOTE: While "UTF16" isn't actually in the FileSystemCmdletProviderEncoding enum, it *seems* like it should work, so it is also included here.
                return [System.Text.Encoding]::Unicode
            }
            'Ascii' {
                return [System.Text.Encoding]::Ascii
            }
            'Default' {
                return [System.Text.Encoding]::Default
            }
            'Oem' {
                # @see https://stackoverflow.com/a/14583739/17152
                return [System.Text.Encoding]::GetEncoding($Host.CurrentCulture.TextInfo.OEMCodePage)
            }
            'BigEndianUTF32' {
                return $allEncodingMap['UTF32-BE']
            }
        }

        # Search by pattern (case-insensitive)
        $name = $_ # because $_ will be overwritten
        if ($result = $allEncodingMap.Keys | Where-Object { $_ -ilike $name } | Select-Object -Unique) {
            return $allEncodingMap[$result]
        }

        # No such luck
        Write-Error "The encoding '$name' does not match any available encoding"

    } | Select-Object -Unique
}

# rewrite format.ps1xml to dispaly different encodings by default
function updateFormatting($displayEncodings) {
    $formatFilepath = "$script:scriptDir/unishell.format.ps1xml"

    Get-Content "$script:scriptDir/unishell.format.template.xml" | % {
        switch -regex ($_) {
            '##DEFAULT_ENCODING_TABLE_HEADERS##' {
                $displayEncodings | % {
                    "<TableColumnHeader>"
                    "<Label>$_</Label>"
                    "<Alignment>Right</Alignment>"
                    "</TableColumnHeader>"
                }
                break
            }
            '##DEFAULT_ENCODING_TABLE_ITEMS##' {
                $displayEncodings | % {
                    "<TableColumnItem>"
                    "<Alignment>Right</Alignment>"
                    "<ScriptBlock>((`$_.'$_' |%{ `$_.ToString('X2') }) -join ' ').PadLeft(12)</ScriptBlock>"
                    "</TableColumnItem>"
                }
                break
            }
            '##ENCODING_LIST_ITEMS##' {
                $displayEncodings | % {
                    "<ListItem>"
                    "<Label>$_</Label>"
                    "<ScriptBlock>(`$_.'$_' |%{ `$_.ToString('X2') }) -join ' '</ScriptBlock>"
                    "</ListItem>"
                }
                break
            }
            default { $_ }
        }
    } | Out-File $formatFilepath -Encoding ascii

    # force refresh
    Update-FormatData -AppendPath $formatFilepath
    Update-FormatData
}

updateFormatting $defaultDisplayEncodings

# minimally-processed stub data for all codepoints from UnicodeData.txt, meant to be
# quick to load. Full set of properties and encodings are computed lazily as needed.
[UnicodeStubData] $unicodeStubData = $null
[UnicodeStubData] $nerdFontStubData = $null

class CodepointCollection {
    [Dictionary[int, Codepoint]] $ByCodepoint = [Dictionary[int, Codepoint]]::new()
    [Dictionary[string, List[Codepoint]]] $ByName = [Dictionary[string, List[Codepoint]]]::new()

    [void] Add([Codepoint] $item) {
        $this.ByCodepoint.Add($item.Codepoint, $item)

        $this.ByName[$item.Name] ??= [List[Codepoint]]::new()
        $this.ByName[$item.Name].Add($item)
    }

    [bool] TryGetByCodepoint([int] $codepoint, [ref] $ref)
    {
        return $this.ByCodepoint.TryGetValue($codepoint, $ref)
    }

    [bool] TryGetByName([string] $name, [ref] $ref)
    {
        return $this.ByName.TryGetValue($name, $ref)
    }
}

class UnicodeStubData {
    [Dictionary[int, List[PSCustomObject]]] $ByCodepoint = [Dictionary[int, List[PSCustomObject]]]::new()
    [Dictionary[string, List[PSCustomObject]]] $ByName = [Dictionary[string, List[PSCustomObject]]]::new()

    UnicodeStubData() {
        $this.AddProperties()
    }

    hidden [void] AddProperties() {
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Names -Value { return $this.get_Names() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Count -Value { return $this._count }
    }

    hidden [int] $_count = 0

    [void] Add([PSCustomObject] $item) {
        $this.ByCodepoint[$item.Codepoint] ??= [List[PSCustomObject]]::new()
        $this.ByCodepoint[$item.Codepoint].Add($item)

        $this.ByName[$item.Name] ??= [List[PSCustomObject]]::new()
        $this.ByName[$item.Name].Add($item)

        $this._count++
    }

    [string[]] get_Names() { return $this.ByName.Keys }
}

# cache of fully-processed codepoint data
$charData = [CodepointCollection]::new()


# lookup functions for range-based info

$rangeBlock = $null
function getRange([int] $codepoint) {
    & $script:rangeBlock $codepoint
}

$ageBlock = $null
function getAge([int] $codepoint) {
    & $script:ageBlock $codepoint
}

$blocksBlock = $null
function getBlock([int] $codepoint) {
    & $script:blocksBlock $codepoint
}

$scriptsBlock = $null
function getScript([int] $codepoint) {
    & $script:scriptsBlock $codepoint
}

$lineBreakBlock = $null
function getLineBreak([int] $codepoint) {
    & $script:lineBreakBlock $codepoint
}

# generates a function body (scriptblock) that looks up a given codepoint
#  from a collection of individual codepoints or codepoint ranges, and returns a
#  value associated with that codepoint or range. This is how most of the Unicode
#  data files are organized.
function genRangedLookup($path, $fieldRegex, $fieldValueFunc, $defaultValue) {
    # parse the file and generate the range data once
    $rangeList = New-Object 'System.Collections.Generic.List[hashtable]'

    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path $path).Path, [System.Text.Encoding]::UTF8)) {
        if ($line -cmatch "^(?<start>[A-F0-9]{4,6})(\.\.(?<end>[A-F0-9]{4,6}))?$fieldRegex") {
            $start = [Convert]::ToInt32($matches['start'], 16)
            $end = if ($matches['end']) { [Convert]::ToInt32($matches['end'], 16) } else { $start }
            $rangeList.Add(@{ start = $start; end = $end; value = (& $fieldValueFunc) })
        }
    }

    # close over the data in the function body, only do lookups on invocation
    {
        param($codepoint)
        foreach ($range in $rangeList) {
            if ($codepoint -ge $range.start -and $codepoint -le $range.end) {
                return $range.value
            }
        }
        return $defaultValue
    }.GetNewClosure()
}

# do the minimal amount of stub data loading such that all info
# can later be lazily computed if/when a specific codepoint is requested
function loadStub {
    # bail if already initialized
    if ($script:unicodeStubData) {
        Write-Debug "Data already initialized"
        return
    }

    $script:unicodeStubData = loadUnicodeData $script:unicodeDataPath
    $script:nerdFontStubData = loadNerdFontData $script:nerdFontDataPath

    $global:xyzzy = @{
        unicodeStubData = $unicodeStubData
        nerdFontStubData = $nerdFontStubData
    }

    $script:rangeBlock = {
        param($codepoint)
        foreach ($range in $rangeList) {
            if ($codepoint -ge $range.start -and $codepoint -le $range.end) {
                return $range.start
            }
        }
    }.GetNewClosure()

    # initial parsing of DerivedAge.txt file
    #  (contains info pertaining to the Unicode version in which a codepoint was initially introduced)
    $script:ageBlock = genRangedLookup $script:derivedAgePath  ' *; (?<ver>[\d\.]+)' { $matches['ver'] } 'Unassigned'

    # initial parsing of Blocks.txt file
    #  (contains info about what named block a codepoint resides in)
    $script:blocksBlock = genRangedLookup $script:blocksPath  '; (?<block>[a-zA-Z0-9 \-]+)' { $matches['block'] } 'Unassigned'

    # initial parsing of Scripts.txt file
    #  (contains info about what script a codepoint is expressed in)
    $script:scriptsBlock = genRangedLookup $script:scriptsPath  ' *?; (?<script>[A-Za-z0-9_]+?) #' { $matches['script'] } 'Unknown'

    # initial parsing of LineBreak.txt file
    #  (contains info about line break behavior)
    $script:lineBreakBlock = genRangedLookup $script:lineBreakPath ';(?<class>[A-Z]{2,3}) ' { $lineBreakMappings[$matches['class']] } $lineBreakMappings['XX']
}

function loadUnicodeData([string] $Path) {
    # UnicodeData.txt is a weird hybrid that's mostly a list of individual codepoints,
    #  but also contains a handful of ranges (which are specified in a non-standard way).
    #  Thus the one-off parsing.
    $rangeList = New-Object 'System.Collections.Generic.List[hashtable]'
    $rangeItem = $null

    $headers = @(
        # UnicodeData columns
        # @see https://www.unicode.org/L2/L1999/UnicodeData.html
        'CodeValue',                    # Code value (normative) - Code value in 4-digit hexadecimal format.
        'Name',                         # Character name (normative) - These names match exactly the names published in Chapter 7 of the Unicode Standard, Version 2.0, except for the two additional characters.
        'Category',                     # General category - normative / informative (see below) - This is a useful breakdown into various "character types" which can be used as a default categorization in implementations. See below for a brief explanation.
        'CanonicalCombiningClasses',    # Canonical combining classes (normative) - The classes used for the Canonical Ordering Algorithm in the Unicode Standard. These classes are also printed in Chapter 4 of the Unicode Standard.
        'BidiCategory',                 # Bidirectional category (normative) - See the list below for an explanation of the abbreviations used in this field. These are the categories required by the Bidirectional Behavior Algorithm in the Unicode Standard. These categories are summarized in Chapter 3 of the Unicode Standard.
        'DecompositionMapping',         # Character decomposition mapping (normative) - In the Unicode Standard, not all of the mappings are full (maximal) decompositions. Recursive application of look-up for decompositions will, in all cases, lead to a maximal decomposition. The decomposition mappings match exactly the decomposition mappings published with the character names in the Unicode Standard.
        'DecimalDigitValue',            # Decimal digit value (normative) - This is a numeric field. If the character has the decimal digit property, as specified in Chapter 4 of the Unicode Standard, the value of that digit is represented with an integer value in this field
        'DigitValue',                   # Digit value (normative) - This is a numeric field. If the character represents a digit, not necessarily a decimal digit, the value is here. This covers digits which do not form decimal radix forms, such as the compatibility superscript digits
        'NumericValue',                 # Numeric value (normative) - This is a numeric field. If the character has the numeric property, as specified in Chapter 4 of the Unicode Standard, the value of that character is represented with an integer or rational number in this field. This includes fractions as, e.g., "1/5" for U+2155 VULGAR FRACTION ONE FIFTH Also included are numerical values for compatibility characters such as circled numbers.
        'Mirrored',                     # Mirrored (normative) - If the character has been identified as a "mirrored" character in bidirectional text, this field has the value "Y"; otherwise "N". The list of mirrored characters is also printed in Chapter 4 of the Unicode Standard.
        'Unicode1_0Name',               # Unicode 1.0 Name (informative) - This is the old name as published in Unicode 1.0. This name is only provided when it is significantly different from the Unicode 3.0 name for the character.
        '10646CommentField',            # 10646 comment field (informative) - This is the ISO 10646 comment field. It is in parantheses in the 10646 names list.
        'UppercaseMapping',             # Uppercase mapping (informative) - Upper case equivalent mapping. If a character is part of an alphabet with case distinctions, and has an upper case equivalent, then the upper case equivalent is in this field. See the explanation below on case distinctions. These mappings are always one-to-one, not one-to-many or many-to-one. This field is informative.
        'LowercaseMapping',             # Lowercase mapping (informative) - Similar to Uppercase mapping
        'TitlecaseMapping'              # Titlecase mapping (informative) - Similar to Uppercase mapping
    )

    $result = [UnicodeStubData]::new()

    Import-Csv -Encoding:UTF8 -Delimiter:';' -Path:$Path -Header:$headers | ForEach-Object {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Codepoint' -Value ([Convert]::ToInt32($_.CodeValue, 16))

        if ($_.Name -cmatch '^\<(?<rangeName>[a-zA-Z0-9 ]+?), (?<marker>First|Last)>$') {
            $_.Name = $matches['rangeName']
            if ($matches['marker'] -eq 'First') {
                $rangeItem = @{start = $_.Codepoint; end = 0}
            }
            else {
                $rangeItem['end'] = $_.Codepoint
                $rangeList.Add($rangeItem)
            }
        }

        $result.Add($_)

    }

    return $result
}

<#

.NOTES

To regenerate, visit https://www.nerdfonts.com/cheat-sheet and run:

```javascript
copy($$('#glyphCheatSheet > div.column')
    .map(el => ({
        name: el.querySelector('.class-name').innerText,
        value: parseInt(el.querySelector('.codepoint').innerText, 16),
        removed: el.querySelector('.corner-text')?.innerText === 'removed'
     }))
    .sort((a, b) => a.value - b.value)
    .map(o => [o.value.toString(16).toUpperCase(), o.name, o.removed ? 'removed' : ''].join(';')).join('\n'))
```

This generates a delimited format with the following columns:

| Field | Name       | Explanation                              |
|------:|:-----------|------------------------------------------|
|     0 | CodeValue  | Code value in hexadecimal format.        |
|     1 | Name       | The name of the glyph.                   |
|     2 | Removed    | Mostly blank, some have "removed".       |

#>
function loadNerdFontData([string] $Path) {
    $headers = @('CodeValue', 'Name', 'Removed')

    $result = [UnicodeStubData]::new()

    Import-Csv -Encoding UTF8 -Delimiter:';' -Header:$headers -Path:$Path | ForEach-Object {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Codepoint' -Value ([Convert]::ToInt32($_.CodeValue, 16))

        # None should be ranges.
        $result.Add($_)
    }

    return $result
}

function nerdFontNames([PSCustomObject[]] $items) {
    return $items | Sort-Object Removed, Name | ForEach-Object { $_.Removed ? ('{0} (removed)' -f $_.Name) : $_.Name }
}

class Codepoint : ICloneable {
    [string] $Name
    [string] $RawValue
    [int] $Codepoint
    [string] $Category
    [string] $CanonicalCombiningClasses
    [string] $BidiCategory

    [string] get_Value() { return displayValue $this.Codepoint $this.RawValue }
    [string] get_CodepointString() { return 'U+{0:X4}' -f $this.Codepoint }
    [string] get_Block() { return getBlock $this.codepoint }
    [string] get_Plane() { return plane $this.codepoint }
    [string] get_UnicodeVersion() { return getAge $this.codepoint }
    [string] get_Script() { return getScript $this.codepoint }
    [string] get_LineBreakClass() { return getLineBreak $this.Codepoint }

    [string] $DecompositionMapping
    [Nullable[int]] $DecimalDigitValue
    [string] $DigitValue
    [string] $NumericValue
    [bool] $Mirrored
    [Nullable[int]] $UppercaseMapping
    [Nullable[int]] $LowercaseMapping
    [Nullable[int]] $TitlecaseMapping

    [string[]] $AlternativeNames

    Codepoint([PSCustomObject] $unicodeData, [PSCustomObject[]] $nerdFontData)
    {
        $this.Name = $unicodeData.Name
        if ($unicodeData.Unicode1_0Name -and ($unicodeData.Name -like '<*>')) {
            $this.Name = '{0} {1}' -f $this.Name, $unicodeData.Unicode1_0Name
        }

        $this.Codepoint                 = $unicodeData.Codepoint
        $this.RawValue                  = getValue $this.Codepoint
        $this.Category                  = $script:generalCategoryMappings[$unicodeData.Category]
        $this.CanonicalCombiningClasses = $script:combiningClassMappings[$unicodeData.CanonicalCombiningClasses]
        $this.BidiCategory              = $script:bidiCategoryMappings[$unicodeData.BidiCategory]
        $this.DecompositionMapping      = $unicodeData.DecompositionMapping
        $this.DecimalDigitValue         = $unicodeData.DecimalDigitValue
        $this.DigitValue                = $unicodeData.DigitValue
        $this.NumericValue              = $unicodeData.NumericValue
        $this.Mirrored                  = ($unicodeData.Mirrored -eq 'Y')
        $this.UppercaseMapping          = if ($unicodeData.UppercaseMapping) { [Convert]::ToInt32($unicodeData.UppercaseMapping, 16) } else { $null }
        $this.LowercaseMapping          = if ($unicodeData.LowercaseMapping) { [Convert]::ToInt32($unicodeData.LowercaseMapping, 16) } else { $null }
        $this.TitlecaseMapping          = if ($unicodeData.TitlecaseMapping) { [Convert]::ToInt32($unicodeData.TitlecaseMapping, 16) } else { $null }
        $this.AlternativeNames          = nerdFontNames $nerdFontData

        $this.AddProperties()
    }

    Codepoint([int] $Codepoint, [PSCustomObject[]] $nerdFontData)
    {
        switch ($nerdFontData.Length) {
            0 { throw [ArgumentException]::new('No font data found', 'nerdFontData') }
            1 {
                # Only one.
                $this.Name = $nerdFontData[0].Name
            }
            default {
                # Prefer un-removed names.
                [PSCustomObject[]] $unremoved = $nerdFontData | Where-Object { !$_.Removed } | Select-Object -First 1
                $this.Name = switch ($unremoved.Length) {
                    0 { $nerdFontData[0].Name } # All are removed.  Just return the first item's name then
                    default { $unremoved[0].Name }
                }
                $this.AlternativeNames = nerdFontNames ($nerdFontData | Where-Object Name -cne $this.Name)
            }
        }

        $this.Codepoint = $Codepoint
        $this.RawValue = getValue $this.Codepoint

        $this.AddProperties()
    }

    Codepoint([int] $Codepoint, [string] $name)
    {
        $this.Codepoint = $Codepoint
        $this.Name = $name
        $this.RawValue = getValue $this.Codepoint

        $this.AddProperties()
    }

    hidden [void] AddProperties() {
        $this.PSTypeNames.Add('unishell.codepoint')

        Add-Member -InputObject $this -MemberType ScriptProperty -Name CodepointString -Value { $this.get_CodepointString() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Value -Value { $this.get_Value() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Block -Value { $this.get_Block() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Plane -Value { $this.get_Plane() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name UnicodeVersion -Value { $this.get_UnicodeVersion() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name Script -Value { $this.get_Script() }
        Add-Member -InputObject $this -MemberType ScriptProperty -Name LineBreakClass -Value { $this.get_LineBreakClass() }

        # add noteproperties to the codepoint object for each available encoding
        $encodingProps = @{}
        foreach ($enc in $script:allEncodings) {
            $bytes = if ($null -eq $this.RawValue) { , @() } else { $enc.GetBytes($this.RawValue) }
            $encodingProps.Add($enc.WebName, [byte[]]$bytes)
        }

        Add-Member -InputObject $this -NotePropertyMembers $encodingProps
    }

    [object] Clone()
    {
        $result = [Codepoint] $this.MemberwiseClone()
        $result.AddProperties()
        return $result
    }
}

# gets string representation of a specified codepoint,
# with support for unpaired surrogates
function getValue($codepoint) {
    if (($codepoint -lt 0) -or ($codepoint -gt 0x10ffff)) {
        Write-Error ("{0} (0x{0:X4}) is not a valid codepoint" -f $codepoint)
        $null
    }
    elseif (($codepoint -lt 0xD800) -or ($codepoint -gt 0xDFFF)) {
        [char]::ConvertFromUtf32($codepoint)
    }
    else {
        [char] $codepoint
    }
}

# gets the fully-processing codepoint object
function getCharByCodepoint {

    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int] $codepoint
    )

    process {
        write-verbose "getCharByCodepoint $codepoint"
        [Codepoint] $result = $null

        if ($script:charData.TryGetByCodepoint($codepoint, [ref] $result)) {
            write-verbose "----> hit"
            return $result
        }

        write-verbose "----> miss"
        $result = loadChar $codepoint
        $script:charData.Add($result)
        return $result
    }
}

function loadChar([int] $codepoint) {
    write-verbose "loadChar $codepoint"
    [List[PSCustomObject]] $unicodeData = $script:unicodeStubData.ByCodepoint[$codepoint] ?? @()
    [List[PSCustomObject]] $nerdFontData = $script:nerdFontStubData.ByCodepoint[$codepoint] ?? @()

    if ($unicodeData) {
        write-verbose "----> unicodedata found"
        return [Codepoint]::new($unicodeData, $nerdFontData)
    }

    # no info for this specific codepoint in $unicodeStubData,
    # so it maybe it's in the middle of some UnicodeData.txt range.
    # If so, getRange tells us the range's first codepoint
    $rangeStartCodepoint = getRange $codepoint
    if ($rangeStartCodepoint) {
        # add a stub entry pointing to the data of the range start codepoint
        $unicodeData = $script:unicodeStubData.ByCodepoint[$codepoint] = $script:unicodeStubData.ByCodepoint[$rangeStartCodepoint]

        return [Codepoint]::new($unicodeData, $nerdFontData)
    }

    if ($nerdFontData) {
        write-verbose "----> nerdfont only"
        return [Codepoint]::new($codepoint, $nerdFontData)
    }

    # otherwise, this codepoint must be unassigned
    write-verbose "----> unassigned"
    return [Codepoint]::new($codepoint, 'Unassigned')
}

function getCharByName {

    [OutputType([Codepoint[]])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string] $Name
    )

    process {
        write-verbose "getCharByName $Name"

        if ($result = $script:charData.ByName[$name]) {
            write-verbose "---> hit"
            return $result
        }

        write-verbose "---> miss"

        $unicodeData = $script:unicodeStubData.ByName[$name] ?? @()
        $nerdFontData = $script:nerdFontStubData.ByName[$name] ?? @()

        if ($unicodeData) {
            write-verbose "---> found unicode data"
            $result = [Codepoint]::new($unicodeData, $nerdFontData)
            $script:charData.Add($result)
            return $result
        }

        # no info for this specific codepoint in $unicodeStubData,
        # so it maybe it's in the middle of some UnicodeData.txt range.
        # If so, getRange tells us the range's first codepoint
        if ($nerdFontData) {
            write-verbose "---> found nerdfont data $_"
            return $nerdFontData | getCharByCodepoint
        }

        write-verbose "---> no data found"

        Write-Error -Category ObjectNotFound -Message "For codepoint: $Name"
    }
}

function getByName([string] $name) {
    $script:unicodeStubData.Names -like $name | getCharByName
    $script:nerdFontStubData.Names -like $name | getCharByName
}

# for a given input string, takes care of
# - Splitting the string into codepoints (handling surrogate pairs and unpaired surrogates)
# - Computing the fancy display combiner lines based on the string's
#     "text units" & combining character codepoints
# - Cobbling together core codepoint data and hidden display fields into
#     final resulting object
function expandString($inputString) {
    # .NET's API for splitting a string into "text units", i.e. boundaries of
    #  surrogate pairs and/or base codepoints followed by combining codepoints.
    #  Limited... does not handle ZWJ, emoji modifiers, etc
    $textElemPositions = [System.Globalization.StringInfo]::ParseCombiningCharacters($inputString)

    $idx = 0
    $elemStart = $textElemPositions[$idx]
    $elemEnd = if ($textElemPositions.Length -gt ($idx + 1)) {
        $textElemPositions[$idx + 1] - 1
    }
    else {
        $inputString.Length - 1
    }

    for ($i = 0; $i -lt $inputString.Length; $i++) {
        $codepoint = try {
            [Char]::ConvertToUtf32($inputString, $i)
        }
        catch {
            # handle case of unpaired surrogates
            [int]$inputString[$i]
        }

        # base/core codepoint properties
        # the object we return will have hidden display fields, so create a copy
        #  instead of mutating the original
        $baseChar = (getCharByCodepoint $codepoint).Clone()

        # is this a paired high surrogate?
        $isHS = ([Char]::IsHighSurrogate($inputString[$i]) -and ($i -lt $inputString.Length - 1) -and ([Char]::IsLowSurrogate($inputSTring[$i + 1])))

        # is the current codepoint a base codepoint
        $baseCurrent = $i -eq $elemStart
        # was there a base codepoint earlier in the string
        $baseBefore = $i -gt 0
        # are there any base codepoints later in the string
        $baseAfter = $idx -lt ($textElemPositions.Length - 1)

        # were there any codepoints earlier in the string
        $pointBefore = $i -gt $elemStart
        # are there any codepoints later in the string
        $pointAfter = ($i -lt ($elemEnd - 1)) -or (($i -eq ($elemEnd - 1)) -and !$isHS)

        # add the hidden display fields
        if (!(Get-Member -InputObject $baseChar -Name '_Combiner')) {
            # combiner line computations
            $combinerA =
                if ($baseCurrent -and $baseBefore -and $baseAfter) { ([char]0x251C) }
                elseif ($baseCurrent -and $baseBefore -and !$baseAfter) { [char]0x2514 }
                elseif ($baseCurrent -and !$baseBefore -and $baseAfter) { ([char]0x250C) }
                elseif ($baseCurrent -and !$baseBefore -and !$baseAfter) { ([char]0x2500) }
                elseif (!$baseCurrent -and $baseBefore -and $baseAfter) { ([char]0x2502) }
                elseif (!$baseCurrent -and $baseBefore -and !$baseAfter) { " " }
                else { Write-Error "Unexpected $i $elemStart $elemEnd $idx $baseCurrent $baseBefore $baseAfter" }

            $combinerB =
                if ($pointBefore -and $pointAfter) { ([char]0x251C) }
                elseif ($pointBefore -and !$pointAfter) { ([char]0x2514) }
                elseif (!$pointBefore -and $pointAfter) { ([char]0x252C) }
                else { ([char]0x2500) }

            Add-Member -InputObject $baseChar -NotePropertyName '_Combiner' -NotePropertyValue "$combinerA$combinerB"
        }

        if (!(Get-Member -InputObject $baseChar -Name '_OriginatingString')) {
            Add-Member -InputObject $baseChar -NotePropertyName '_OriginatingString' -NotePropertyValue $inputString
        }

        Write-Output $baseChar

        if ($isHS) {
            $i++
        }

        if ($i -eq $elemEnd) {
            $idx++
            $elemStart = $elemEnd + 1
            $elemEnd = if ($textElemPositions.Length -gt ($idx + 1)) {
                $textElemPositions[$idx + 1] - 1
            }
            else {
                $inputString.Length - 1
            }
        }
    }
}