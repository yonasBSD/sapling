
#require symlink tar unzip no-eden

  $ newrepo repo
  $ ln -s nothing dangling

avoid tar warnings about old timestamp

  $ sl ci -d '2000-01-01 00:00:00 +0000' -qAm 'add symlink'

  $ sl archive -t files ../archive
  $ sl archive -t tar -p tar ../archive.tar
  $ sl archive -t zip -p zip ../archive.zip

files

  $ cd "$TESTTMP"
  $ cd archive
  $ f dangling
  dangling -> nothing

tar

  $ cd "$TESTTMP"
  $ tar xf archive.tar
  $ cd tar
  $ f dangling
  dangling -> nothing

#if unziplinks
zip

  $ cd "$TESTTMP"
  $ unzip archive.zip > /dev/null 2>&1
  $ cd zip
  $ f dangling
  dangling -> nothing
#endif

  $ cd ..
