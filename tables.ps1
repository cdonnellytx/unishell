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

$lineBreakMappings = @{
    'BK'  = 'BK - Mandatory Break'
    'CR'  = 'CR - Carriage Return'
    'LF'  = 'LF - Line Feed'
    'CM'  = 'CM - Combining Mark'
    'NL'  = 'NL - Next Line'
    'SG'  = 'SG - Surrogate'
    'WJ'  = 'WJ - Word Joiner'
    'ZW'  = 'ZW - Zero Width Space'
    'GL'  = 'GL - Non-breaking ("Glue")'
    'SP'  = 'SP - Space'
    'ZWJ' = 'ZWJ - Zero Width Joiner'
    'B2'  = 'Break Opportunity Before and After'
    'BA'  = 'BA - Break After'
    'BB'  = 'BB - Break Before'
    'HY'  = 'HY - Hyphen'
    'CB'  = 'CB - Contingent Break Opportunity'
    'CL'  = 'CL - Close Punctuation'
    'CP'  = 'CP - Close Parenthesis'
    'EX'  = 'EX - Exclamation/Interrogation'
    'IN'  = 'IN - Inseparable'
    'NS'  = 'NS - Nonstarter'
    'OP'  = 'OP - Open Punctuation'
    'QU'  = 'QU - Quotation'
    'IS'  = 'IS - Infix Numeric Separator'
    'NU'  = 'NU - Numeric'
    'PO'  = 'PO - Postfix Numeric'
    'PR'  = 'PR - Prefix Numeric'
    'SY'  = 'SY - Symbols Allowing Break After'
    'AI'  = 'AI - Ambiguous (Alphabetic or Ideographic)'
    'AL'  = 'AL - Alphabetic'
    'CJ'  = 'CJ - Conditional Japanese Starter'
    'EB'  = 'EB - Emoji Base'
    'EM'  = 'EM - Emoji modifier'
    'H2'  = 'H2 - Hangul LV Syllable'
    'H3'  = 'H3 - Hangul LVT Syllable'
    'HL'  = 'HL - Hebrew Letter'
    'ID'  = 'ID - Ideographic'
    'JL'  = 'JL - Hangul L Jamo'
    'JV'  = 'JV - Hangul V Jamo'
    'JT'  = 'JT - Hangul T Jamo'
    'RI'  = 'RI - Regional Indicator'
    'SA'  = 'SA - Complex Context Dependent (South East Asian)'
    'XX'  = 'XX - Unknown'
}

function plane($codepoint) {
    if($codepoint -lt 0) { Write-Error "Invalid codepoint" }
    elseif($codepoint -le 0xFFFF){ '0 - Basic Multilingual Plane' }
    elseif($codepoint -le 0x1FFFF) { '1 - Supplementary Multilingual Plane'}
    elseif($codepoint -le 0x2FFFF) { '2 - Supplementary Ideographic Plane' }
    elseif($codepoint -le 0x3FFFF) { '3 - Tertiary Ideographic Plane' }
    elseif($codepoint -le 0x4FFFF) { '4 - Unassigned' }
    elseif($codepoint -le 0x5FFFF) { '5 - Unassigned' }
    elseif($codepoint -le 0x6FFFF) { '6 - Unassigned' }
    elseif($codepoint -le 0x7FFFF) { '7 - Unassigned' }
    elseif($codepoint -le 0x8FFFF) { '8 - Unassigned' }
    elseif($codepoint -le 0x9FFFF) { '9 - Unassigned' }
    elseif($codepoint -le 0xAFFFF) { '10 - Unassigned' }
    elseif($codepoint -le 0xBFFFF) { '11 - Unassigned' }
    elseif($codepoint -le 0xCFFFF) { '12 - Unassigned' }
    elseif($codepoint -le 0xDFFFF) { '13 - Unassigned' }
    elseif($codepoint -le 0xEFFFF) { '14 - Supplementary Special-purpose Plane' }
    elseif($codepoint -le 0xFFFFF) { '15 - Supplementary Private Use Area-A' }
    elseif($codepoint -le 0x10FFFF) { '16 - Supplementary Private Use Area-B'}
    else { Write-Error "Invalid codepoint" }
}
