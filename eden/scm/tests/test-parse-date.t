
#require no-eden


This runs with TZ="GMT"

  $ sl init repo
  $ cd repo
  $ echo "test-parse-date" > a
  $ sl add a
  $ sl ci -d "2006-02-01 13:00:30" -m "rev 0"
  $ echo "hi!" >> a
  $ sl ci -d "2006-02-01 13:00:30 -0500" -m "rev 1"
  $ echo >> .hgtags
  $ sl ci -Aq -d "2006-04-15 13:30" -m "Hi"
  $ sl backout --merge -d "2006-04-15 13:30 +0200" -m "rev 3" 'desc(1)'
  reverting a
  changeset cac74e007661 backs out changeset 25a1420a55f8
  merging with changeset cac74e007661
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -d "1150000000 14400" -m "rev 4 (merge)"
  $ echo "fail" >> a
  $ sl ci -d "should fail" -m "fail"
  sl: parse error: invalid date: 'should fail'
  [255]
  $ sl ci -d "100000000000000000 1400" -m "fail"
  sl: parse error: invalid date: '100000000000000000 1400'
  [255]
  $ sl ci -d "100000 1400000" -m "fail"
  sl: parse error: invalid date: '100000 1400000'
  [255]

Check with local timezone other than GMT and with DST

  $ TZ="PST+8PDT+7,M4.1.0/02:00:00,M10.5.0/02:00:00"
  $ export TZ

PST=UTC-8 / PDT=UTC-7
Summer time begins on April's first Sunday at 2:00am,
and ends on October's last Sunday at 2:00am.

This sleep is to defeat Rust chrono crate's unix local TZ caching. It refreshes
it's cache if it's been more than 1 second since since last check.
  $ sleep 1

  $ sl debugrebuildstate
  $ echo "a" > a
#if windows
Windows $TZ handling is a workaround to the time-0.1.42 crate.
It does not support DST. See comments in pyhgtime/src/lib.rs:tzset.
Workaround it in this test by providing timezone explicitly.
  $ sl ci -d "2006-07-15 13:30 -0700" -m "summer@UTC-7"
#else
  $ sl ci -d "2006-07-15 13:30" -m "summer@UTC-7"
#endif
  $ sl debugrebuildstate
  $ echo "b" > a
  $ sl ci -d "2006-07-15 13:30 +0500" -m "summer@UTC+5"
  $ sl debugrebuildstate
  $ echo "c" > a
  $ sl ci -d "2006-01-15 13:30" -m "winter@UTC-8"
  $ sl debugrebuildstate
  $ echo "d" > a
  $ sl ci -d "2006-01-15 13:30 +0500" -m "winter@UTC+5"
  $ sl log --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

Test issue1014 (fractional timezones)

  $ sl debugdate "1000000000 -16200" # 0430
  internal: 1000000000 -16200
  standard: Sun Sep 09 06:16:40 2001 +0430
  $ sl debugdate "1000000000 -15300" # 0415
  internal: 1000000000 -15300
  standard: Sun Sep 09 06:01:40 2001 +0415
  $ sl debugdate "1000000000 -14400" # 0400
  internal: 1000000000 -14400
  standard: Sun Sep 09 05:46:40 2001 +0400
  $ sl debugdate "1000000000 0"      # GMT
  internal: 1000000000 0
  standard: Sun Sep 09 01:46:40 2001 +0000
  $ sl debugdate "1000000000 14400"  # -0400
  internal: 1000000000 14400
  standard: Sat Sep 08 21:46:40 2001 -0400
  $ sl debugdate "1000000000 15300"  # -0415
  internal: 1000000000 15300
  standard: Sat Sep 08 21:31:40 2001 -0415
  $ sl debugdate "1000000000 16200"  # -0430
  internal: 1000000000 16200
  standard: Sat Sep 08 21:16:40 2001 -0430
  $ sl debugdate "Sat Sep 08 21:16:40 2001 +0430"
  internal: 999967600 -16200
  standard: Sat Sep 08 21:16:40 2001 +0430
  $ sl debugdate "Sat Sep 08 21:16:40 2001 -0430"
  internal: 1000000000 16200
  standard: Sat Sep 08 21:16:40 2001 -0430

Tests below use relative dates and expect "now" to not be unix epoch.

  $ setconfig devel.default-date='2020-01-01 05:00:00'

Test 12-hours times

  $ sl debugdate "2006-02-01 1:00:30PM +0000"
  internal: 1138798830 0
  standard: Wed Feb 01 13:00:30 2006 +0000
  $ sl debugdate "1:00:30PM" > /dev/null

Normal range

  $ sl log -d -1

Negative range

  $ sl log -d "--2"
  sl: parse error: invalid date: '--2'
  [255]

Whitespace only

  $ sl log -d " "
  sl: parse error: invalid date: ' '
  [255]

Date containing percent format specifiers (should not crash with IndexError)

  $ sl log -d "+%s"
  sl: parse error: invalid date: '+%s'
  [255]
  $ sl log -d "+%YY%dd%mm"
  sl: parse error: invalid date: '+%YY%dd%mm'
  [255]
  $ sl log -d "%d"
  sl: parse error: invalid date: '%d'
  [255]
  $ sl log -d "+%s" -T '{date|date}\n'
  sl: parse error: invalid date: '+%s'
  [255]

Test date formats with '>' or '<' accompanied by space characters

  $ sl log -d '>' --template '{date|date}\n'
  sl: parse error: invalid date: '>'
  [255]
  $ sl log -d '<' --template '{date|date}\n'
  sl: parse error: invalid date: '<'
  [255]

  $ sl log -d ' >' --template '{date|date}\n'
  sl: parse error: invalid date: ' >'
  [255]
  $ sl log -d ' <' --template '{date|date}\n'
  sl: parse error: invalid date: ' <'
  [255]

  $ sl log -d '> ' --template '{date|date}\n'
  sl: parse error: invalid date: '> '
  [255]
  $ sl log -d '< ' --template '{date|date}\n'
  sl: parse error: invalid date: '< '
  [255]

  $ sl log -d ' > ' --template '{date|date}\n'
  sl: parse error: invalid date: ' > '
  [255]
  $ sl log -d ' < ' --template '{date|date}\n'
  sl: parse error: invalid date: ' < '
  [255]

  $ sl log -d '>02/01' --template '{date|date}\n'
  $ sl log -d '<02/01' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d ' >02/01' --template '{date|date}\n'
  $ sl log -d ' <02/01' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d '> 02/01' --template '{date|date}\n'
  $ sl log -d '< 02/01' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d ' > 02/01' --template '{date|date}\n'
  $ sl log -d ' < 02/01' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d '>02/01 ' --template '{date|date}\n'
  $ sl log -d '<02/01 ' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d ' >02/01 ' --template '{date|date}\n'
  $ sl log -d ' <02/01 ' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d '> 02/01 ' --template '{date|date}\n'
  $ sl log -d '< 02/01 ' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

  $ sl log -d ' > 02/01 ' --template '{date|date}\n'
  $ sl log -d ' < 02/01 ' --template '{date|date}\n'
  Sun Jan 15 13:30:00 2006 +0500
  Sun Jan 15 13:30:00 2006 -0800
  Sat Jul 15 13:30:00 2006 +0500
  Sat Jul 15 13:30:00 2006 -0700
  Sun Jun 11 00:26:40 2006 -0400
  Sat Apr 15 13:30:00 2006 +0200
  Sat Apr 15 13:30:00 2006 +0000
  Wed Feb 01 13:00:30 2006 -0500
  Wed Feb 01 13:00:30 2006 +0000

Test that '<' and '>' are inclusive
  $ THISCOMMIT=$(sl log -r . -T "{date|hgdate}")
  $ sl log -r "date(\"<$THISCOMMIT\") & date(\">$THISCOMMIT\")" -T "{node}"
  cefbcc8b3dc9345a744a11713abfe40a53d4fc9d (no-eol)

Test issue 3764 (interpreting 'today' and 'yesterday')
  $ echo "hello" >> a
  >>> import datetime
  >>> today_date = datetime.date(2020,1,1)
  >>> today = today_date.strftime("%b %d")
  >>> yesterday = (today_date - datetime.timedelta(days=1)).strftime("%b %d %Y")
  >>> dates = open('dates', 'w')
  >>> _ = dates.write(today + '\n')
  >>> _ = dates.write(yesterday + '\n')
  >>> dates.close()
  $ sl ci -d "`head -1 dates`" -m "today is a good day to code"
  $ sl log -d today --template '{desc}\n'
  today is a good day to code
  $ echo "goodbye" >> a
  $ sl ci -d "`tail -1 dates`" -m "the time traveler's code"
  $ sl log -d yesterday --template '{desc}\n'
  the time traveler's code
  $ echo "foo" >> a
  $ sl commit -d now -m 'Explicitly committed now.'
  $ sl log -d today --template '{desc}\n'
  Explicitly committed now.
  today is a good day to code

Test parsing various ISO8601 forms

#if no-windows
(TZ with DST does not work on Windows)
  $ sl debugdate "2016-07-27T12:10:21"
  internal: 1469646621 * (glob)
  standard: Wed Jul 27 12:10:21 2016 -0700
#endif
  $ sl debugdate "2016-07-27T12:10:21Z"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000
  $ sl debugdate "2016-07-27T12:10:21+00:00"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000
  $ sl debugdate "2016-07-27T121021Z"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000

#if no-windows
(TZ with DST does not work on Windows)
  $ sl debugdate "2016-07-27 12:10:21"
  internal: 1469646621 * (glob)
  standard: Wed Jul 27 12:10:21 2016 -0700
#endif
  $ sl debugdate "2016-07-27 12:10:21Z"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000
  $ sl debugdate "2016-07-27 12:10:21+00:00"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000
  $ sl debugdate "2016-07-27 121021Z"
  internal: 1469621421 0
  standard: Wed Jul 27 12:10:21 2016 +0000

Test parsing extra forms

  $ setconfig devel.default-date="1996-03-07 14:00:01Z"
  $ sl debugdate 'now'
  internal: 826207201 0
  standard: Thu Mar 07 14:00:01 1996 +0000
  $ sl debugdate '6h ago'
  internal: 826185601 0
  standard: Thu Mar 07 08:00:01 1996 +0000
  $ sl debugdate --range 'today'
  start: 826185600 (Thu Mar 07 00:00:00 1996 -0800)
    end: 826272000 (Fri Mar 08 00:00:00 1996 -0800)
  $ sl debugdate --range 'yesterday to today'
  start: 826099200 (Wed Mar 06 00:00:00 1996 -0800)
    end: 826272000 (Fri Mar 08 00:00:00 1996 -0800)
  $ sl debugdate --range 'since 5 months ago'
  start: 813057121 (Sat Oct 07 09:12:01 1995 +0000)
    end: 253402300799 (Fri Dec 31 23:59:59 9999 +0000)
  $ sl debugdate --range '2000 to 2001'
  start: 946713600 (Sat Jan 01 00:00:00 2000 -0800)
    end: 1009872000 (Tue Jan 01 00:00:00 2002 -0800)
  $ sl debugdate --range 'before 2001'
  start: -2208988800 (Mon Jan 01 00:00:00 1900 +0000)
    end: 978336000 (Mon Jan 01 00:00:00 2001 -0800)

#if no-windows
(Windows parsing are affected by System Local settings that are unclear how to
override in tests. Cannot assume English here.)

Test parsing months

  $ for i in Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec; do
  >   sl log -d "$i 2018" -r null
  > done
#endif
