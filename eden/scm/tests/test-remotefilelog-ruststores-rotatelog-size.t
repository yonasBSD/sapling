
#require no-eden

  $ eagerepo

  $ . "$TESTDIR/library.sh"
  $ setconfig remotefilelog.debug=False
  $ setconfig workingcopy.rust-checkout=true

  $ newserver master

  $ clone master shallow --noupdate
  $ cd shallow

  $ echo uuuuuuuuuuu > u
  $ sl commit -qAm u
  $ echo vvvvvvvvvvv > v
  $ sl commit -qAm v
  $ echo wwwwwwwwwww > w
  $ sl commit -qAm w
  $ echo xxxxxxxxxxx > x
  $ sl commit -qAm x
  $ echo yyyyyyyyyyy > y
  $ sl commit -qAm y
  $ echo zzzzzzzzzzz > z
  $ sl commit -qAm z
  $ sl push -q -r tip --to master --create
  $ cd ..

  $ filter() {
  >   grep -v manifest | grep -v aux | grep 'datastore.*log'
  > }

Test max-bytes-per-log
  $ clone master shallow2 --noupdate
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 12 *0* (glob)
  $ cd shallow2

  $ cp .sl/config .sl/config.bak
  $ setconfig indexedlog.data.max-bytes-per-log=10
  $ sl up -q 'desc(u)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 69 *0* (glob)
  * 12 *1* (glob)
  $ sl up -q 'desc(v)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 69 *0* (glob)
  * 69 *1* (glob)
  * 12 *2* (glob)
  $ sl up -q 'desc(w)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 69 *0* (glob)
  * 69 *1* (glob)
  * 69 *2* (glob)
  * 12 *3* (glob)

  $ setconfig indexedlog.data.max-bytes-per-log=100
  $ sl up -q null
  $ newcachedir

  $ sl up -q 'desc(u)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * * *0* (glob)
  $ sl up -q 'desc(v)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 126 *0* (glob)
  * 12 *1* (glob)
  $ sl up -q 'desc(w)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 126 *0* (glob)
  * 69 *1* (glob)

Test max-log-count
  $ sl up -q null
  $ newcachedir
  $ setconfig indexedlog.data.max-bytes-per-log=10 indexedlog.data.max-log-count=3
  $ sl up -q 'desc(u)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  2
  $ sl up -q 'desc(v)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  3
  $ sl up -q 'desc(w)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  3
  $ sl up -q 'desc(x)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  3
- Verify the log shrinks at the next rotation when the max-log-count is reduced.
  $ setconfig indexedlog.data.max-log-count=2
  $ sl up -q 'desc(y)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  2
  $ sl up -q 'desc(z)'
  $ findfilessorted "$CACHEDIR/master/" | filter | wc -l | sed -e 's/ //g'
  2

Test remotefilelog.cachelimit
  $ cp .sl/config.bak .sl/config
  $ sl up -q null
  $ newcachedir
  $ setconfig remotefilelog.cachelimit=300B
  $ sl up -q 'desc(u)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 69 *0* (glob)
  $ sl up -q 'desc(v)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 126 *0* (glob)
  * 12 *1* (glob)
  $ sl up -q 'desc(w)'
  $ ls_l $(findfilessorted "$CACHEDIR/master/" | filter)
  * 126 *0* (glob)
  * 69 *1* (glob)
