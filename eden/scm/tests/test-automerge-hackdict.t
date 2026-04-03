
#require no-eden

Tests for hackdict automerge file type (KEY => VALUE,).

  $ export HGIDENTITY=sl
  $ configure modern
  $ enable rebase
  $ setconfig automerge.disable-for-noninteractive=False
  $ setconfig automerge.mode=accept
  $ setconfig automerge.merge-algos=sort-inserts

Configure hackdict (KEY => VALUE,) for test.php:
  $ setconfig filetype-patterns.test.php=hackdict
  $ setconfig 'automerge.import-pattern:hackdict=re:^\s*[^()]+\s*=>\s*(.+,\s*)?$'
  $ setconfig 'automerge.import-continuation-pattern:hackdict=re:,\s*$'
  $ setconfig 'automerge.import-key-pattern:hackdict=re:^\s*([^()]+?)\s*=>\s*'

=== HACKDICT SINGLE-LINE TESTS ===

Single-line namespace-keyed dict entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    App\existing => ExistingHandler::class,\n    App\feature_b => FeatureBHandler::class,\n
  > |/  # B/test.php=    App\existing => ExistingHandler::class,\n    App\feature_a => FeatureAHandler::class,\n
  > A   # A/test.php=    App\existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  App\existing => ExistingHandler::class,
      App\feature_a => FeatureAHandler::class,
      App\feature_b => FeatureBHandler::class,

Unindented dict entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=existing => ExistingHandler::class,\nfeature_b => FeatureBHandler::class,\n
  > |/  # B/test.php=existing => ExistingHandler::class,\nfeature_a => FeatureAHandler::class,\n
  > A   # A/test.php=existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  existing => ExistingHandler::class,
  feature_a => FeatureAHandler::class,
  feature_b => FeatureBHandler::class,

String-keyed dict entries auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    'Existing' => ExistingPlugin::class,\n    'Bravo' => BravoPlugin::class,\n
  > |/  # B/test.php=    'Existing' => ExistingPlugin::class,\n    'Alpha' => AlphaPlugin::class,\n
  > A   # A/test.php=    'Existing' => ExistingPlugin::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  'Existing' => ExistingPlugin::class,
      'Alpha' => AlphaPlugin::class,
      'Bravo' => BravoPlugin::class,

Nameof-style multi-word dict keys auto-merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=      nameof ExistingConfig => BypassReason::LEGACY,\n      nameof NewConfigB => BypassReason::LEGACY,\n
  > |/  # B/test.php=      nameof ExistingConfig => BypassReason::LEGACY,\n      nameof NewConfigA => BypassReason::LEGACY,\n
  > A   # A/test.php=      nameof ExistingConfig => BypassReason::LEGACY,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  nameof ExistingConfig => BypassReason::LEGACY,
        nameof NewConfigA => BypassReason::LEGACY,
        nameof NewConfigB => BypassReason::LEGACY,

=== HACKDICT EDGE CASES ===

Header pattern takes priority over continuation pattern:
Lines matching both header (=>) and continuation (ends with ,) are treated
as separate entries, not grouped into the previous entry.

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=  'existing' => ExistingHandler::class,\n  'bravo' => BravoHandler::class,\n  'charlie' => CharlieHandler::class,\n
  > |/  # B/test.php=  'existing' => ExistingHandler::class,\n  'alpha' => AlphaHandler::class,\n  'delta' => DeltaHandler::class,\n
  > A   # A/test.php=  'existing' => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  'existing' => ExistingHandler::class,
    'alpha' => AlphaHandler::class,
    'bravo' => BravoHandler::class,
    'charlie' => CharlieHandler::class,
    'delta' => DeltaHandler::class,

Quoted key => quoted value (single-line) auto-merges:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=  'existing' => 'existing_val',\n  'key_b' => 'val_b',\n
  > |/  # B/test.php=  'existing' => 'existing_val',\n  'key_a' => 'val_a',\n
  > A   # A/test.php=  'existing' => 'existing_val',\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  'existing' => 'existing_val',
    'key_a' => 'val_a',
    'key_b' => 'val_b',

Quoted key => quoted value (multi-line wrap) auto-merges:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=  'existing' => 'existing_val',\n  'key_b' =>\n    'val_b',\n
  > |/  # B/test.php=  'existing' => 'existing_val',\n  'key_a' =>\n    'val_a',\n
  > A   # A/test.php=  'existing' => 'existing_val',\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  'existing' => 'existing_val',
    'key_a' =>
      'val_a',
    'key_b' =>
      'val_b',

Duplicate dict key with different values MUST conflict:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=existing\n  'same_key' => BarClass::class,\n
  > |/  # B/test.php=existing\n  'same_key' => FooClass::class,\n
  > A   # A/test.php=existing\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
  warning: 1 conflicts while merging test.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

=== REGRESSION: Hack use statements still work ===

Hack use statements auto-merge for non-opted .php files:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/use.php=existing\nuse FooLib;\n
  > |/  # B/use.php=existing\nuse BarLib;\n
  > A   # A/use.php=existing\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging use.php
   lines 2-3 have been resolved by automerge algorithms
  $ sl cat -r tip use.php
  existing
  use BarLib;
  use FooLib;

Non-opted .php files do NOT get hackdict automerge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/nonopted.php=  EXISTING = "EXISTING";\n  BAR = "BAR";\n
  > |/  # B/nonopted.php=  EXISTING = "EXISTING";\n  FOO = "FOO";\n
  > A   # A/nonopted.php=  EXISTING = "EXISTING";\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging nonopted.php
  warning: 1 conflicts while merging nonopted.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

=== MULTI-LINE ENTRY GROUPING TESTS ===

Multi-line dict entry merge (header on one line, value on next):

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    App\existing => ExistingHandler::class,\n    App\feature_b =>\n      FeatureBHandler::class,\n
  > |/  # B/test.php=    App\existing => ExistingHandler::class,\n    App\feature_a =>\n      FeatureAHandler::class,\n
  > A   # A/test.php=    App\existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-5 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  App\existing => ExistingHandler::class,
      App\feature_a =>
        FeatureAHandler::class,
      App\feature_b =>
        FeatureBHandler::class,

Mixed single and multi-line dict entries merge:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    App\existing => ExistingHandler::class,\n    App\feature_b =>\n      FeatureBHandler::class,\n
  > |/  # B/test.php=    App\existing => ExistingHandler::class,\n    App\feature_a => FeatureAHandler::class,\n
  > A   # A/test.php=    App\existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
   lines 2-4 have been resolved by automerge algorithms
  $ sl cat -r tip test.php
  App\existing => ExistingHandler::class,
      App\feature_a => FeatureAHandler::class,
      App\feature_b =>
        FeatureBHandler::class,

Multi-line duplicate key MUST conflict:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    App\existing => ExistingHandler::class,\n    App\same_key =>\n      HandlerB::class,\n
  > |/  # B/test.php=    App\existing => ExistingHandler::class,\n    App\same_key =>\n      HandlerA::class,\n
  > A   # A/test.php=    App\existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
  warning: 1 conflicts while merging test.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

Multi-line entry with unmatched continuation line bails out:

  $ newrepo
  $ drawdag <<'EOS'
  > B C # C/test.php=    App\existing => ExistingHandler::class,\n    App\foo =>\n      // this is a comment\n
  > |/  # B/test.php=    App\existing => ExistingHandler::class,\n    App\bar => BarHandler::class,\n
  > A   # A/test.php=    App\existing => ExistingHandler::class,\n
  > EOS
  $ sl rebase -r $C -d $B
  rebasing * "C" (glob)
  merging test.php
  warning: 1 conflicts while merging test.php! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
