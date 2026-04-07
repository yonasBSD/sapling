
#require no-eden

#inprocess-hg-incompatible

  $ eagerepo

Setup repo

  $ sl init repo
  $ cd repo
  $ touch a
  $ sl commit -Aqm a
  $ mkdir dir
  $ touch dir/b
  $ sl commit -Aqm b
  $ sl up -q 'desc(a)'
  $ echo x >> a
  $ sl commit -Aqm a2

Test that warning is shown whenever ':' is used with singlecolonwarn set

  $ sl log -T '{node} ' -r '3903775176ed42b1458a6281db4a0ccf4d9f287a:desc(a2)' --config tweakdefaults.singlecolonwarn=1
  warning: use of ':' is deprecated
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)
  $ sl log -T '{node} ' -r '3903775176ed42b1458a6281db4a0ccf4d9f287a:desc(a2)'
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)
  $ sl log -T '{node} ' -r ':desc(a2)' --config tweakdefaults.singlecolonwarn=1
  warning: use of ':' is deprecated
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)
  $ sl log -T '{node} ' -r ':desc(a2)'
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)
  $ sl log -T '{node} ' -r '3903775176ed42b1458a6281db4a0ccf4d9f287a:' --config tweakdefaults.singlecolonwarn=1
  warning: use of ':' is deprecated
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)
  $ sl log -T '{node} ' -r '3903775176ed42b1458a6281db4a0ccf4d9f287a:'
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)

In this testcase warning should not be shown
  $ sl log -T '{node} ' -r ':' --config tweakdefaults.singlecolonwarn=1
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)

Check that the custom message can be used
  $ sl log -T '{node} ' -r '3903775176ed42b1458a6281db4a0ccf4d9f287a:' --config tweakdefaults.singlecolonwarn=1 --config tweakdefaults.singlecolonmsg="hey stop that"
  warning: hey stop that
  3903775176ed42b1458a6281db4a0ccf4d9f287a 62acd743a793874dbb46d28fca2d4cd6a5568e99 ae5108b653e2f2d15099970dec82ee0198e23d98  (no-eol)

Check that we can abort as well
  $ sl log -T '{node} ' -r '0:' --config tweakdefaults.singlecolonabort=1
  abort: use of ':' is deprecated
  [255]
  $ sl log -T '{node} ' -r '0:' --config tweakdefaults.singlecolonabort=1 --config tweakdefaults.singlecolonmsg="no more colons"
  abort: no more colons
  [255]
