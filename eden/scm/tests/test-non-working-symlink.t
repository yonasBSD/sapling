#require windows no-eden

Make sure Windows symlink support respects absence of windowssymlinks requirement
  $ newrepo
  $ grep -v windowssymlinks .sl/requires > .sl/requires.new
  $ mv .sl/requires.new .sl/requires
  $ echo bar > foo
  $ ln -s foo foolink
  $ sl add -q
  $ sl diff foolink --git
  diff --git a/foolink b/foolink
  new file mode 100644
  --- /dev/null
  +++ b/foolink
  @@ -0,0 +1,1 @@
  +foo
  \ No newline at end of file
  $ sl commit -m "foo->bar"
  $ sl show . foolink --git
  commit:      481a741b0020
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo foolink
  description:
  foo->bar
  
  
  diff --git a/foolink b/foolink
  new file mode 100644
  --- /dev/null
  +++ b/foolink
  @@ -0,0 +1,1 @@
  +foo
  \ No newline at end of file
