param(
    $UnicodeDataPath
)

$scriptDir = Split-Path $psCommandPath

if (-not $UnicodeDataPath) {
    $UnicodeDataPath = Join-Path $scriptDir 'UnicodeData.txt'
}
if (-not (Test-Path $UnicodeDataPath)) {
    Write-Error "Cannot find Unicode data file at $unicodeDataPath"
    exit
} 

$charData = $null

$generalCategoryMappings = @{
    'Lu' = 'Lu - Letter, Uppercase'
    'Ll' = 'Ll - Letter, Lowercase'
    'Lt' = 'Lt - Letter, Titlecase'
    'Mn' = 'Mn - Mark, Non-Spacing'
    'Mc' = 'Mc - Mark, Spacing Combining'
    'Me' = 'Me - Mark, Enclosing'
    'Nd' = 'Nd - Number, Decimal Digit'
    'Nl' = 'Nl - Number, Letter'
    'No' = 'No - Number, Other'
    'Zs' = 'Zs - Separator, Space'
    'Zl' = 'Zl - Separator, Line'
    'Zp' = 'Zp - Separator, Paragraph'
    'Cc' = 'Cc - Other, Control'
    'Cf' = 'Cf - Other, Format'
    'Cs' = 'Cs - Other, Surrogate'
    'Co' = 'Co - Other, Private Use'
    'Cn' = 'Cn - Other, Not Assigned'
    'Lm' = 'Lm - Letter, Modifier'
    'Lo' = 'Lo - Letter, Other'
    'Pc' = 'Pc - Punctuation, Connector'
    'Pd' = 'Pd - Punctuation, Dash'
    'Ps' = 'Ps - Punctuation, Open'
    'Pe' = 'Pe - Punctuation, Close'
    'Pi' = 'Pi - Punctuation, Initial quote'
    'Pf' = 'Pf - Punctuation, Final quote'
    'Po' = 'Po - Punctuation, Other'
    'Sm' = 'Sm - Symbol, Math'
    'Sc' = 'Sc - Symbol, Currency'
    'Sk' = 'Sk - Symbol, Modifier'
    'So' = 'So - Symbol, Other'
}

$combiningClassMappings = @{
    '0'   = '0 - Spacing, split, enclosing, reordrant, and Tibetan subjoined'
    '1'   = '1 - Overlays and interior'
    '7'   = '7 - Nuktas'
    '8'   = '8 - Hiragana/Katakana voicing marks'
    '9'   = '9 - Viramas'
    '10'  = '10 - Start of fixed position classes'
    '199' = '199 - End of fixed position classes'
    '200' = '200 - Below left attached'
    '202' = '202 - Below attached'
    '204' = '204 - Below right attached'
    '208' = '208 - Left attached (reordrant around single base character)'
    '210' = '210 - Right attached'
    '212' = '212 - Above left attached'
    '214' = '214 - Above attached'
    '216' = '216 - Above right attached'
    '218' = '218 - Below left'
    '220' = '220 - Below'
    '222' = '222 - Below right'
    '224' = '224 - Left (reordrant around single base character)'
    '226' = '226 - Right'
    '228' = '228 - Above left'
    '230' = '230 - Above'
    '232' = '232 - Above right'
    '233' = '233 - Double below'
    '234' = '234 - Double above'
    '240' = '240 - Below (iota subscript)'
}

$bidiCategoryMappings = @{
    'L'   = 'L - Left-to-Right'
    'LRE' = 'LRE - Left-to-Right Embedding'
    'LRO' = 'LRO - Left-to-Right Override'
    'R'   = 'R - Right-to-Left'
    'AL'  = 'AL - Right-to-Left Arabic'
    'RLE' = 'RLE - Right-to-Left Embedding'
    'RLO' = 'RLO - Right-to-Left Override'
    'PDF' = 'PDF - Pop Directional Format'
    'EN'  = 'EN - European Number'
    'ES'  = 'ES - European Number Separator'
    'ET'  = 'ET - European Number Terminator'
    'AN'  = 'AN - Arabic Number'
    'CS'  = 'CS - Common Number Separator'
    'NSM' = 'NSM - Non-Spacing Mark'
    'BN'  = 'BN - Boundary Neutral'
    'B'   = 'B - Paragraph Separator'
    'S'   = 'S - Segment Separator'
    'WS'  = 'WS - Whitespace'
    'ON'  = 'ON - Other Neutrals'
}
function loadCharData {
    Write-Progress -Activity 'Loading unicode data file'
    $script:charData = Get-Content $script:unicodeDataPath | % {
        $line = $_
        $fields = $line.Split(';')
        $code = [Convert]::ToInt32($fields[0], 16)
        $value = 
        if (($code -lt 55296) -or ($code -gt 57343)) {
            [char]::convertfromutf32($code)
        }
        else {
            $null
        }
        $name = $fields[1]
        if ($fields[10]) {
            $name = "$name $($fields[10])"
        }

        [pscustomobject]@{
            Value                     = $value
            Codepoint                 = "U+" + $fields[0]
            Name                      = $name
            Category                  = $generalCategoryMappings[$fields[2]]
            CanonicalCombiningClasses = $combiningClassMappings[$fields[3]]
            BidiCategory              = $bidiCategoryMappings[$fields[4]]
            DecompositionMapping      = $fields[5]
            DecimalDigitValue         = if ($fields[6]) { [int] $fields[6] } else {$null}
            DigitValue                = $fields[7]
            NumericValue              = $fields[8]
            Mirrored                  = ($fields[9] -eq 'Y')
            #     Comment              = $fields[11]
            UppercaseMapping          = if ($fields[12]) { "U+" + $fields[12] } else { $null }
            LowercaseMapping          = if ($fields[13]) { "U+" + $fields[13] } else { $null }
            TitlecaseMapping          = if ($fields[14]) { "U+" + $fields[14] } else { $null }

            ASCII                     = [byte[]]@(if ($value) { [System.Text.Encoding]::ASCII.GetBytes($value) } else { $null })
            ISO88591                  = [byte[]]@(if ($value) { [System.Text.Encoding]::GetEncoding(28591).GetBytes($value) } else { $null })
            UTF8                      = [byte[]]@(if ($value) { [System.Text.Encoding]::UTF8.GetBytes($value) } else { $null })
            UTF16                     = [byte[]]@(if ($value) { [System.Text.Encoding]::Unicode.GetBytes($value) } else { $null })
        }
    }
    Write-Progress -Activity 'Loading unicode data file' -Completed
}

function Get-CharData {
    if (!$script:charData) {
        loadCharData
    }

    $script:charData
}

Export-ModuleMember -Function 'Get-CharData'