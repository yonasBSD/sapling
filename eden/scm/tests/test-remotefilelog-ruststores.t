
#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo

  $ . "$TESTDIR/library.sh"

  $ newserver master

  $ clone master shallow --noupdate
  $ cd shallow

  $ echo x > x
  $ sl commit -qAm x
  $ ls_l .sl/store/indexedlogdatastore | grep log
  *      59 log (glob)
  $ ls_l .sl/store/indexedloghistorystore | grep log
  *     127 log (glob)
  $ ls_l .sl/store/manifests/indexedlogdatastore | grep log
  *     101 log (glob)
  $ ls_l .sl/store/manifests/indexedloghistorystore | grep log
  *     124 log (glob)

  $ echo y > y
  $ sl commit -qAm y
  $ ls_l .sl/store/indexedlogdatastore | grep log
  *     106 log (glob)
  $ ls_l .sl/store/indexedloghistorystore | grep log
  *     242 log (glob)
  $ ls_l .sl/store/manifests/indexedlogdatastore | grep log
  *     237 log (glob)
  $ ls_l .sl/store/manifests/indexedloghistorystore | grep log
  *     236 log (glob)

  $ echo z > z
  $ sl commit -qAm z
  $ ls_l .sl/store/indexedlogdatastore | grep log
  *     153 log (glob)
  $ ls_l .sl/store/indexedloghistorystore | grep log
  *     357 log (glob)
  $ ls_l .sl/store/manifests/indexedlogdatastore | grep log
  *     417 log (glob)
  $ ls_l .sl/store/manifests/indexedloghistorystore | grep log
  *     348 log (glob)
