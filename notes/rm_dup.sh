#!/usr/bin/env bash
set -euo pipefail

FILE="vulkan_guide.tex"
BAKDIR="bak"

if [[ ! -f "$FILE" ]]; then
  echo "Error: $FILE not found in current directory." >&2
  exit 1
fi

mkdir -p "$BAKDIR"
cp "$FILE" "$BAKDIR/${FILE}.bak"

# Use Perl to:
#  - slurp the whole file (-0777)
#  - find all occurrences of \addcontentsline{...}{...}{...} (dot matches newline with /s)
#  - normalize whitespace inside the matched entry for comparison (collapse runs of whitespace to single space)
#  - keep the first occurrence of each normalized entry and drop later duplicates
#
# The script writes to a temporary file and moves it back to the original filename (atomic-ish).
perl -0777 -e '
  use strict;
  use warnings;

  local $/;
  my $s = <>;

  my %seen;
  my $out = "";
  my $last = 0;

  # global regex to find logical \addcontentsline{...}{...}{...} blocks, allowing newlines
  while ($s =~ /\\addcontentsline\b\{.*?\}\{.*?\}\{.*?\}/sg) {
    my $mstart = $-[0];
    my $mend   = $+[0];
    $out .= substr($s, $last, $mstart - $last);                # text before match
    my $entry = substr($s, $mstart, $mend - $mstart);         # the matched logical entry

    # Normalize whitespace (collapse runs of whitespace/newlines to single space)
    # Also trim leading/trailing whitespace inside the normalized form for consistent comparison.
    (my $norm = $entry) =~ s/\s+/ /g;
    $norm =~ s/^\s+|\s+$//g;

    if (!$seen{$norm}++) {
      $out .= $entry;   # keep first occurrence (preserve original formatting)
    } else {
      # duplicate: skip adding this entry to $out (effectively removing it)
    }
    $last = $mend;
  }

  # append any remaining tail of the file
  $out .= substr($s, $last) if $last < length($s);

  print $out;
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

echo "Done. Backup saved as $BAKDIR/${FILE}.bak"

