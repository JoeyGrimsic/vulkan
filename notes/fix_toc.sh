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

# Pipe the file into Perl (Perl reads from STDIN with <>), write to a temp file, then move it back.
cat "$FILE" | perl -0777 -Mutf8 -CS -e '
  use strict;
  use warnings;

  # read whole file from STDIN
  local $/;
  my $s = <>;
  defined $s or die "failed to read input";

  # helper: given $s and $pos at a "{" character, return (content_between_braces, new_pos_after_closing_brace)
  sub extract_braced {
    my ($s, $pos) = @_;
    die "extract_braced: pos not at {" unless substr($s, $pos, 1) eq "{";
    my $i = $pos + 1;
    my $len = length($s);
    my $depth = 0;
    my $start = $i;
    while ($i < $len) {
      my $ch = substr($s, $i, 1);
      if ($ch eq "{") { $depth++; }
      elsif ($ch eq "}") {
        if ($depth == 0) {
          my $content = substr($s, $start, $i - $start);
          return ($content, $i + 1); # pos after closing brace
        } else { $depth--; }
      }
      $i++;
    }
    die "Unbalanced braces starting at position $pos";
  }

  # normalize whitespace: collapse runs of whitespace/newlines to single space and trim
  sub norm_ws {
    my ($t) = @_;
    $t =~ s/\s+/ /gs;
    $t =~ s/^\s+|\s+$//g;
    return $t;
  }

  # --- Step 1: collect existing addcontentsline entries into %existing
  my %existing;
  {
    pos($s) = 0;
    while ($s =~ /\\addcontentsline\b/sg) {
      pos($s) = $+[0]; # move to just after match
      next unless $s =~ /\G\s*\{/gc;
      my $b1 = pos($s) - 1;
      my ($arg1, $p1) = extract_braced($s, $b1);
      pos($s) = $p1;
      next unless $s =~ /\G\s*\{/gc;
      my $b2 = pos($s) - 1;
      my ($arg2, $p2) = extract_braced($s, $b2);
      pos($s) = $p2;
      next unless $s =~ /\G\s*\{/gc;
      my $b3 = pos($s) - 1;
      my ($arg3, $p3) = extract_braced($s, $b3);
      pos($s) = $p3;
      $existing{ norm_ws($arg2) . "|" . norm_ws($arg3) } = 1;
    }
  }

  # --- Step 2: insert missing TOC entries after starred headings
  my $out = "";
  my $last = 0;
  pos($s) = 0;
  while ($s =~ /\\(section|subsection|subsubsection|paragraph)\*\s*\{/sg) {
    my $level = $1;
    my $cmd_start = $-[0];
    my $brace_pos = $+[0] - 1; # position of the "{"
    # append text before this heading
    $out .= substr($s, $last, $cmd_start - $last);
    # extract heading title (resilient to nested braces / line wraps)
    my ($title, $after_pos) = extract_braced($s, $brace_pos);
    # append the original heading as-is
    $out .= substr($s, $cmd_start, $after_pos - $cmd_start);
    $last = $after_pos;
    my $norm_title = norm_ws($title);
    my $key = "$level|$norm_title";
    if (!exists $existing{$key}) {
      $existing{$key} = 1;
      # insert a single-line addcontentsline right after the heading
      $out .= "\\addcontentsline{toc}{$level}{$norm_title}\n";
    }
    pos($s) = $last;
  }
  $out .= substr($s, $last) if $last < length($s);

  # --- Step 3: deduplicate addcontentsline entries (keep first occurrence)
  my %seen;
  my $final = "";
  my $p = 0;
  pos($out) = 0;
  while ($out =~ /\\addcontentsline\b/sg) {
    my $mstart = $-[0];
    my $mend_pos = $+[0];
    $final .= substr($out, $p, $mstart - $p);
    pos($out) = $mend_pos;
    # extract three braced args robustly
    next unless $out =~ /\G\s*\{/gc;
    my ($a1, $pp1) = extract_braced($out, pos($out)-1);
    pos($out) = $pp1;
    next unless $out =~ /\G\s*\{/gc;
    my ($a2, $pp2) = extract_braced($out, pos($out)-1);
    pos($out) = $pp2;
    next unless $out =~ /\G\s*\{/gc;
    my ($a3, $pp3) = extract_braced($out, pos($out)-1);
    pos($out) = $pp3;
    my $key = norm_ws($a2) . "|" . norm_ws($a3);
    my $entry_text = substr($out, $mstart, $pp3 - $mstart);
    if (!$seen{$key}++) {
      $final .= $entry_text;
    } else {
      # skip duplicate
    }
    $p = $pp3;
  }
  $final .= substr($out, $p) if $p < length($out);

  print $final;
' > "$FILE.tmp"

# atomic-ish replace
mv "$FILE.tmp" "$FILE"

echo "Done. Backup saved as $BAKDIR/${FILE}.bak"
