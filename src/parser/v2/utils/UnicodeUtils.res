// UnicodeUtils.res
// Sole owner of visual-width math.
// Per design.md §Unicode Policy, requirements.md REQ-22.

// East Asian Wide ranges (approximate; covers CJK + emoji core).
// Source: Unicode East Asian Width property — simplified for parser use.
let isWide = (cp: int): bool => {
  // CJK Unified Ideographs and key wide ranges
  (cp >= 0x1100 && cp <= 0x115F) || // Hangul Jamo
  (cp >= 0x2E80 && cp <= 0x303E) || // CJK Radicals/Kangxi
  (cp >= 0x3041 && cp <= 0x33FF) || // Hiragana/Katakana/CJK Symbols
  (cp >= 0x3400 && cp <= 0x4DBF) || // CJK Ext A
  (cp >= 0x4E00 && cp <= 0x9FFF) || // CJK Unified
  (cp >= 0xA000 && cp <= 0xA4CF) || // Yi
  (cp >= 0xAC00 && cp <= 0xD7A3) || // Hangul Syllables
  (cp >= 0xF900 && cp <= 0xFAFF) || // CJK Compat Ideographs
  (cp >= 0xFE30 && cp <= 0xFE4F) || // CJK Compat Forms
  (cp >= 0xFF00 && cp <= 0xFF60) || // Fullwidth Forms
  (cp >= 0xFFE0 && cp <= 0xFFE6) || // Fullwidth Signs
  (cp >= 0x1F300 && cp <= 0x1FAFF) || // Emoji blocks
  (cp >= 0x20000 && cp <= 0x2FFFF) // CJK Ext B+
}

// Combining marks have zero visual width.
let isCombining = (cp: int): bool => {
  (cp >= 0x0300 && cp <= 0x036F) ||
  (cp >= 0x1AB0 && cp <= 0x1AFF) ||
  (cp >= 0x1DC0 && cp <= 0x1DFF) ||
  (cp >= 0x20D0 && cp <= 0x20FF) ||
  (cp >= 0xFE20 && cp <= 0xFE2F) ||
  cp == 0x200D // ZWJ
}

// Visual width of a single grapheme cluster (narrow=1, wide=2, combining=0).
// We approximate "grapheme" as "first code point" for non-emoji and treat
// ZWJ-joined emoji as one wide unit by collapsing combining sequences.
let graphemeWidth = (s: string): int => {
  if s == "" {
    0
  } else {
    let cp = String.codePointAt(s, 0)->Option.getOr(0x20)
    if isCombining(cp) {
      0
    } else if isWide(cp) {
      2
    } else {
      1
    }
  }
}

// Iterate grapheme clusters of a string. The fold receives:
//   (acc, ~start: int byte offset, ~end_: int byte offset (exclusive), ~width: visual width)
// For simplicity we treat each code-point as a cluster except that combining
// marks (incl. ZWJ) attach to the previous cluster.
let foldGraphemes = (
  s: string,
  f: ('a, ~start: int, ~end_: int, ~width: int) => 'a,
  init: 'a,
): 'a => {
  let n = String.length(s)
  let acc = ref(init)
  let i = ref(0)
  while i.contents < n {
    let cp = String.codePointAt(s, i.contents)->Option.getOr(0x20)
    let cuLen = if cp > 0xFFFF { 2 } else { 1 }
    let clusterStart = i.contents
    let clusterEnd = ref(clusterStart + cuLen)
    // Extend the cluster while:
    //   (a) the next code point is combining (incl. ZWJ U+200D), OR
    //   (b) the previous code point was a ZWJ — the joiner pulls the next
    //       code point into the same grapheme cluster (emoji ZWJ sequences).
    let keepExtending = ref(true)
    let lastWasZwj = ref(cp == 0x200D)
    while keepExtending.contents && clusterEnd.contents < n {
      let nextCp = String.codePointAt(s, clusterEnd.contents)->Option.getOr(-1)
      if nextCp < 0 {
        keepExtending := false
      } else if isCombining(nextCp) || lastWasZwj.contents {
        clusterEnd := clusterEnd.contents + (nextCp > 0xFFFF ? 2 : 1)
        lastWasZwj := nextCp == 0x200D
      } else {
        keepExtending := false
      }
    }
    let width = if isCombining(cp) {
      0
    } else if isWide(cp) {
      2
    } else {
      1
    }
    acc := f(acc.contents, ~start=clusterStart, ~end_=clusterEnd.contents, ~width)
    i := clusterEnd.contents
  }
  acc.contents
}

// Visual column count of `s` with a starting column (tab-aware).
// `tabSize` defaults to 4: a tab advances to the next multiple of `tabSize`.
// ZWJ (U+200D) emoji sequences such as `👨‍👩‍👧` are treated as a SINGLE
// grapheme: the code point immediately following a ZWJ does not advance
// the column.
let visualWidth = (s: string, ~startCol: int=0, ~tabSize: int=4, ()): int => {
  let col = ref(startCol)
  let n = String.length(s)
  let i = ref(0)
  let prevWasZwj = ref(false)
  while i.contents < n {
    let cp = String.codePointAt(s, i.contents)->Option.getOr(0x20)
    let cuLen = if cp > 0xFFFF { 2 } else { 1 }
    if cp == 0x09 {
      let next = (col.contents / tabSize + 1) * tabSize
      col := next
      prevWasZwj := false
    } else if cp == 0x200D {
      // ZWJ itself contributes 0; mark so the next code point is absorbed.
      prevWasZwj := true
    } else if prevWasZwj.contents {
      // Part of a ZWJ sequence — already counted by the base emoji.
      prevWasZwj := false
    } else if isCombining(cp) {
      ()
    } else if isWide(cp) {
      col := col.contents + 2
    } else {
      col := col.contents + 1
    }
    i := i.contents + cuLen
  }
  col.contents - startCol
}

// Slice a string by byte/code-unit indices.
let slice = (s: string, ~start: int, ~end_: int): string =>
  String.slice(s, ~start, ~end=end_)
