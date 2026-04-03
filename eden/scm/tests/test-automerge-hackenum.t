
#require no-eden

Tests for hackenum automerge file type (NAME = VALUE;).

  $ export HGIDENTITY=sl
  $ configure modern
  $ enable rebase
  $ setconfig automerge.disable-for-noninteractive=False
  $ setconfig automerge.mode=accept
  $ setconfig automerge.merge-algos=sort-inserts

Configure hackenum (NAME = VALUE;) for enum.php:
  $ setconfig filetype-patterns.enum.php=hackenum
  $ setconfig 'automerge.import-pattern:hackenum=re:^\s*\w+(\s+\w+)*\s*=\s*(.+;\s*)?$'
  $ setconfig 'automerge.import-continuation-pattern:hackenum=re:;\s*$'
  $ setconfig 'automerge.import-key-pattern:hackenum=re:^\s*(\w+(\s+\w+)*)\s*=\s*'

=== HACKENUM SINGLE-LINE TESTS ===

String enum entries with mixed quotes auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING = 'EXISTING';\n  FEATURE_B = "FEATURE_B";\n
  > |/  # B/enum.php=  EXISTING = 'EXISTING';\n  FEATURE_A = "FEATURE_A";\n
  > A   # A/enum.php=  EXISTING = 'EXISTING';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING = 'EXISTING';
    FEATURE_A = "FEATURE_A";
    FEATURE_B = "FEATURE_B";

Unindented enum entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=EXISTING = 'EXISTING';\nFEATURE_B = 'FEATURE_B';\n
  > |/  # B/enum.php=EXISTING = 'EXISTING';\nFEATURE_A = 'FEATURE_A';\n
  > A   # A/enum.php=EXISTING = 'EXISTING';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING = 'EXISTING';
  FEATURE_A = 'FEATURE_A';
  FEATURE_B = 'FEATURE_B';

Single-quoted string-valued enum entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING = 'existing';\n  FEATURE_B = 'feature_b';\n
  > |/  # B/enum.php=  EXISTING = 'existing';\n  FEATURE_A = 'feature_a';\n
  > A   # A/enum.php=  EXISTING = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING = 'existing';
    FEATURE_A = 'feature_a';
    FEATURE_B = 'feature_b';

Long enum names auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING = 'existing';\n  VERY_LONG_FEATURE_NAME_BRAVO = 'very_long_feature_name_bravo';\n
  > |/  # B/enum.php=  EXISTING = 'existing';\n  VERY_LONG_FEATURE_NAME_ALPHA = 'very_long_feature_name_alpha';\n
  > A   # A/enum.php=  EXISTING = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING = 'existing';
    VERY_LONG_FEATURE_NAME_ALPHA = 'very_long_feature_name_alpha';
    VERY_LONG_FEATURE_NAME_BRAVO = 'very_long_feature_name_bravo';

Int-valued enum entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING_ID = 12345;\n  NEW_ID_B = 9876543210;\n
  > |/  # B/enum.php=  EXISTING_ID = 12345;\n  NEW_ID_A = 1234567890;\n
  > A   # A/enum.php=  EXISTING_ID = 12345;\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING_ID = 12345;
    NEW_ID_A = 1234567890;
    NEW_ID_B = 9876543210;

Const-typed int entries auto-merge (const int NAME = 12345):

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  const int EXISTING = 100;\n  const int FEATURE_B = 200;\n
  > |/  # B/enum.php=  const int EXISTING = 100;\n  const int FEATURE_A = 300;\n
  > A   # A/enum.php=  const int EXISTING = 100;\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  const int EXISTING = 100;
    const int FEATURE_A = 300;
    const int FEATURE_B = 200;

Multi-line int entries auto-merge (value wraps to next line):

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  int EXISTING = 100;\n  int FEATURE_B =\n    200;\n
  > |/  # B/enum.php=  int EXISTING = 100;\n  int FEATURE_A =\n    300;\n
  > A   # A/enum.php=  int EXISTING = 100;\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  int EXISTING = 100;
    int FEATURE_A =
      300;
    int FEATURE_B =
      200;

Multi-line string entries auto-merge (value on next line without quotes on header):

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  string Existing = 'existing';\n  string FeatureB =\n    'feature_b value';\n
  > |/  # B/enum.php=  string Existing = 'existing';\n  string FeatureA =\n    'feature_a value';\n
  > A   # A/enum.php=  string Existing = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  string Existing = 'existing';
    string FeatureA =
      'feature_a value';
    string FeatureB =
      'feature_b value';

Multi-line string entries auto-merge (quoted value wraps to next line):

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  string Existing = 'existing';\n  string FeatureB =\n    'feature_b';\n
  > |/  # B/enum.php=  string Existing = 'existing';\n  string FeatureA =\n    'feature_a';\n
  > A   # A/enum.php=  string Existing = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  string Existing = 'existing';
    string FeatureA =
      'feature_a';
    string FeatureB =
      'feature_b';

Mixed single-line and multi-line entries merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  string Existing = 'existing';\n  string MultiLine =\n    'multi_value';\n
  > |/  # B/enum.php=  string Existing = 'existing';\n  string SingleLine = 'single_value';\n
  > A   # A/enum.php=  string Existing = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-4 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  string Existing = 'existing';
    string MultiLine =
      'multi_value';
    string SingleLine = 'single_value';

=== HACKENUM EDGE CASES ===

Header pattern takes priority over continuation pattern:
Lines matching both header (NAME =) and continuation (ends with ;) are treated
as separate entries, not grouped into the previous entry.

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING = 'existing';\n  BRAVO = 'bravo';\n  CHARLIE = 'charlie';\n
  > |/  # B/enum.php=  EXISTING = 'existing';\n  ALPHA = 'alpha';\n  DELTA = 'delta';\n
  > A   # A/enum.php=  EXISTING = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  EXISTING = 'existing';
    ALPHA = 'alpha';
    BRAVO = 'bravo';
    CHARLIE = 'charlie';
    DELTA = 'delta';

Unsuccessful merge for non-matching lines:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=existing\nreturn $result;\n
  > |/  # B/enum.php=existing\n$x = 1;\n
  > A   # A/enum.php=existing\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
  warning: 1 conflicts while merging enum.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

Non-opted .php files do NOT get hackenum automerge (core safety invariant):

  $ newrepo
  $ setconfig filetype-patterns.safety.php=hack
  $ drawdag <<'EOS'
  > B C # C/safety.php=  EXISTING = "EXISTING";\n  FEATURE_B = "FEATURE_B";\n
  > |/  # B/safety.php=  EXISTING = "EXISTING";\n  FEATURE_A = "FEATURE_A";\n
  > A   # A/safety.php=  EXISTING = "EXISTING";\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging safety.php
  warning: 1 conflicts while merging safety.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

Duplicate enum name with different values MUST conflict:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  EXISTING = "EXISTING";\n  FOO = "VALUE_B";\n
  > |/  # B/enum.php=  EXISTING = "EXISTING";\n  FOO = "VALUE_A";\n
  > A   # A/enum.php=  EXISTING = "EXISTING";\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
  warning: 1 conflicts while merging enum.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

Duplicate key multi-line entries MUST conflict:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  string Existing = 'existing';\n  string SameName =\n    'value_b';\n
  > |/  # B/enum.php=  string Existing = 'existing';\n  string SameName =\n    'value_a';\n
  > A   # A/enum.php=  string Existing = 'existing';\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
  warning: 1 conflicts while merging enum.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

Delete plus add at same location MUST conflict:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=  ALPHA = "ALPHA";\n  BRAVO = "BRAVO";\n  DELTA = "DELTA";\n
  > |/  # B/enum.php=  ALPHA = "ALPHA";\n  DELTA = "DELTA";\n
  > A   # A/enum.php=  ALPHA = "ALPHA";\n  CHARLIE = "CHARLIE";\n  DELTA = "DELTA";\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
  warning: 1 conflicts while merging enum.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

=== MULTI-TYPE: hackenum file also gets hack use-statement sorting ===

An opted-in .php file matches both hackenum (exact) and hack (glob),
so use-statement conflicts are also auto-resolved:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/enum.php=existing\nuse FooLib;\n
  > |/  # B/enum.php=existing\nuse BarLib;\n
  > A   # A/enum.php=existing\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging enum.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip enum.php
  existing
  use BarLib;
  use FooLib;
