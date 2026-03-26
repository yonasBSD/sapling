
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable stat

Setup repo

  $ sl init repo
  $ cd repo

Test template stat

  $ sl log -r . -T '{stat()}'

  $ seq 50 > a
  $ sl add a
  $ seq 26 75 > b
  $ sl add b
  $ sl commit -m "Added a and b with 50 lines each"
  $ sl log -r . -T '{stat()}'
   a |  50 ++++++++++++++++++++++++++++++++++++++++++++++++++
   b |  50 ++++++++++++++++++++++++++++++++++++++++++++++++++
   2 files changed, 100 insertions(+), 0 deletions(-)

  $ COLUMNS=20 sl log -r . -T '{stat()}'
   a |  50 +++++++++++
   b |  50 +++++++++++
   2 files changed, 100 insertions(+), 0 deletions(-)

  $ seq 50 > b
  $ seq 26 75 > a
  $ sl commit -m "Swapped the files"
  $ sl log -r . -T '{stat()}'
   a |  50 +++++++++++++++++++++++++-------------------------
   b |  50 +++++++++++++++++++++++++-------------------------
   2 files changed, 50 insertions(+), 50 deletions(-)

  $ COLUMNS=20 sl log -r . -T '{stat()}'
   a |  50 +++++-----
   b |  50 +++++-----
   2 files changed, 50 insertions(+), 50 deletions(-)

  $ mkdir dir
  $ seq 50 > dir/a
  $ sl add dir/a
  $ sl commit -m "Added file with 50 lines inside directory dir"
  $ sl log -r . -T '{stat()}'
   dir/a |  50 ++++++++++++++++++++++++++++++++++++++++++++++++++
   1 files changed, 50 insertions(+), 0 deletions(-)

  $ COLUMNS=20 sl log -r . -T '{stat()}'
   dir/a |  50 ++++++++++
   1 files changed, 50 insertions(+), 0 deletions(-)

  $ seq 41 60 > dir/a
  $ sl commit -m "Modified file inside directory dir"
  $ sl log -r . -T '{stat()}'
   dir/a |  50 ++++++++++----------------------------------------
   1 files changed, 10 insertions(+), 40 deletions(-)

  $ COLUMNS=20 sl log -r . -T '{stat()}'
   dir/a |  50 ++--------
   1 files changed, 10 insertions(+), 40 deletions(-)

  $ $PYTHON << EOF
  > with open('binary', 'wb') as f:
  >     f.write(b'\x00\x01\x02\x00' * 10)
  > EOF
  $ sl add binary
  $ sl commit -m "Added binary file"
  $ sl log -r . -T '{stat()}'
   binary |  Bin 
   1 files changed, 0 insertions(+), 0 deletions(-)
  $ sl log -r . -T '{stat("status")}'
  added   binary |  Bin 
   1 files changed, 0 insertions(+), 0 deletions(-)

  $ sl rm -q binary a
  $ echo 3 >> b
  $ echo 4 >> c
  $ sl add c
  $ sl log -r 'wdir()' -T '{stat(status)}'
  removed a      |   50 --------------------------------------------------
  changed b      |    1 +
  removed binary |  Bin 
  added   c      |    1 +
   4 files changed, 2 insertions(+), 50 deletions(-)
