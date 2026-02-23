  $ setconfig drawdag.defaultfiles=false

  $ setconfig grep.use-rust=true

  $ newclientrepo
  $ drawdag <<EOS
  > A  # A/apple = apple\n
  >    # A/banana = banana\n
  >    # A/fruits = apple\nbanana\norange\n
  > EOS
  $ hg go -q $A

  $ hg grep apple | sort
  apple:apple
  fruits:apple

  $ hg grep apple path:fruits
  fruits:apple

  $ hg grep doesntexist
  [1]

  $ hg grep 're:(oops'
  abort: invalid grep pattern 're:(oops': Error { kind: Regex("regex parse error:\n    (?:re:(oops)\n    ^\nerror: unclosed group") }
  [255]

Test -i (ignore case):
  $ hg grep APPLE
  [1]
  $ hg grep -i APPLE | sort
  apple:apple
  fruits:apple

Test -n (line numbers):
  $ hg grep -n banana | sort
  banana:1:banana
  fruits:2:banana

Test -l (files with matches):
  $ hg grep -l apple | sort
  apple
  fruits

Test -w (word regexp):
  $ hg grep app | sort
  apple:apple
  fruits:apple
  $ hg grep -w app
  [1]

Test -V (invert match):
  $ hg grep -V apple path:fruits
  fruits:banana
  fruits:orange

Test -F (fixed strings) - create a file with regex metacharacters:
  $ echo 'a.ple' > dotfile
  $ hg commit -Aqm 'add dotfile'
  $ hg grep -F 'a.ple'
  dotfile:a.ple

Test -A (after context):
  $ hg grep -A 1 apple path:fruits
  fruits:apple
  fruits-banana

Test -B (before context):
  $ hg grep -B 1 banana path:fruits
  fruits-apple
  fruits:banana

Test -C (context - before and after):
  $ hg grep -C 1 banana path:fruits
  fruits-apple
  fruits:banana
  fruits-orange

Test context break between separate match groups:
  $ cat > multiline << 'EOF'
  > line1
  > match1
  > line2
  > line3
  > line4
  > match2
  > line5
  > EOF
  $ hg commit -Aqm 'add multiline'
  $ hg grep -C 1 match path:multiline
  multiline-line1
  multiline:match1
  multiline-line2
  --
  multiline-line4
  multiline:match2
  multiline-line5

Test grep in uncommitted changes:
  $ echo 'findme' > uncommitted_file
  $ hg add uncommitted_file
  $ hg grep findme
  uncommitted_file:findme

Test grep does not search untracked files:
  $ echo 'untracked_content' > untracked_file
  $ hg grep untracked_content
  [1]

Test grep does not search ignored files:
  $ echo 'ignored_content' > ignored_file
  $ echo 'ignored_file' > .gitignore
  $ hg add .gitignore
  $ hg grep ignored_content
  [1]

Test grep does not search removed files:
  $ hg commit -m 'add files'
  $ echo 'removed_content' > removed_file
  $ hg commit -Aqm 'add removed_file'
  $ hg rm removed_file
  $ hg grep removed_content
  [1]

Test grep does search deleted files (tracked but missing from disk):
  $ echo 'deleted_content' > deleted_file
  $ hg commit -Aqm 'add deleted_file'
  $ rm deleted_file
  $ hg grep deleted_content
  deleted_file:deleted_content
