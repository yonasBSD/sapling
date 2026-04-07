
#require no-eden

set up test repo


  $ newclientrepo
  $ echo testcontents > testfile.txt
  $ mkdir testdir
  $ echo dircontents1 > testdir/dirfile1.txt
  $ echo dircontents2 > testdir/dirfile2.txt
  $ sl add -q
  $ sl commit -m "initial commit"

uncopy a single file

  $ sl copy testfile.txt copyfile.txt
  $ sl status -C copyfile.txt
  A copyfile.txt
    testfile.txt
  $ sl uncopy copyfile.txt
  $ sl status -C copyfile.txt
  A copyfile.txt
  $ rm copyfile.txt

uncopy a directory

  $ sl copy -q testdir copydir
  $ sl status -C copydir
  A copydir/dirfile1.txt
    testdir/dirfile1.txt
  A copydir/dirfile2.txt
    testdir/dirfile2.txt
  $ sl uncopy copydir
  $ sl status -C copydir
  A copydir/dirfile1.txt
  A copydir/dirfile2.txt
  $ rm -r copydir

uncopy by pattern

  $ sl copy -q testfile.txt copyfile1.txt
  $ sl copy -q testfile.txt copyfile2.txt
  $ sl status -C copyfile1.txt copyfile2.txt
  A copyfile1.txt
    testfile.txt
  A copyfile2.txt
    testfile.txt
  $ sl uncopy copyfile*
  $ sl status -C copyfile1.txt copyfile2.txt
  A copyfile1.txt
  A copyfile2.txt
  $ rm copyfile*

uncopy nonexistent file

  $ sl uncopy notfound.txt
  notfound.txt: $ENOENT$
  [1]

uncopy a file that was not copied

  $ echo othercontents > otherfile.txt
  $ sl uncopy otherfile.txt
  [1]
  $ sl status -C otherfile.txt
  ? otherfile.txt
