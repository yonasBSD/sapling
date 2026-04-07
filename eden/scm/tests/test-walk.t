
  $ newclientrepo t
  $ mkdir -p beans
  $ for b in kidney navy turtle borlotti black pinto; do
  >     echo $b > beans/$b
  > done
  $ mkdir -p mammals/Procyonidae
  $ for m in cacomistle coatimundi raccoon; do
  >     echo $m > mammals/Procyonidae/$m
  > done
  $ echo skunk > mammals/skunk
  $ echo fennel > fennel
  $ echo fenugreek > fenugreek
  $ echo fiddlehead > fiddlehead
  $ sl addremove
  adding beans/black
  adding beans/borlotti
  adding beans/kidney
  adding beans/navy
  adding beans/pinto
  adding beans/turtle
  adding fennel
  adding fenugreek
  adding fiddlehead
  adding mammals/Procyonidae/cacomistle
  adding mammals/Procyonidae/coatimundi
  adding mammals/Procyonidae/raccoon
  adding mammals/skunk
  $ sl commit -m "commit #0"

  $ sl debugwalk
  f  beans/black                     beans/black
  f  beans/borlotti                  beans/borlotti
  f  beans/kidney                    beans/kidney
  f  beans/navy                      beans/navy
  f  beans/pinto                     beans/pinto
  f  beans/turtle                    beans/turtle
  f  fennel                          fennel
  f  fenugreek                       fenugreek
  f  fiddlehead                      fiddlehead
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ sl debugwalk -I.
  f  beans/black                     beans/black
  f  beans/borlotti                  beans/borlotti
  f  beans/kidney                    beans/kidney
  f  beans/navy                      beans/navy
  f  beans/pinto                     beans/pinto
  f  beans/turtle                    beans/turtle
  f  fennel                          fennel
  f  fenugreek                       fenugreek
  f  fiddlehead                      fiddlehead
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk

  $ cd mammals
  $ sl debugwalk
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk -X ../beans
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk -I '*k'
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'glob:*k'
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'relglob:*k'
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'relglob:*k' .
  f  mammals/skunk  skunk
  $ sl debugwalk -I 're:.*k$'
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'relre:.*k$'
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'path:beans'
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ sl debugwalk -I 'relpath:detour/../../beans'
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle

  $ sl debugwalk 'rootfilesin:'
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ sl debugwalk -I 'rootfilesin:'
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ sl debugwalk 'rootfilesin:.'
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ sl debugwalk -I 'rootfilesin:.'
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ sl debugwalk -X 'rootfilesin:'
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk 'rootfilesin:fennel'
  $ sl debugwalk -I 'rootfilesin:fennel'
  $ sl debugwalk 'rootfilesin:skunk'
  $ sl debugwalk -I 'rootfilesin:skunk'
  $ sl debugwalk 'rootfilesin:beans'
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ sl debugwalk -I 'rootfilesin:beans'
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ sl debugwalk 'rootfilesin:mammals'
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'rootfilesin:mammals'
  f  mammals/skunk  skunk
  $ sl debugwalk 'rootfilesin:mammals/'
  f  mammals/skunk  skunk
  $ sl debugwalk -I 'rootfilesin:mammals/'
  f  mammals/skunk  skunk
  $ sl debugwalk -X 'rootfilesin:mammals'
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon

  $ sl debugwalk .
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk -I.
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk Procyonidae
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon

  $ cd Procyonidae
  $ sl debugwalk .
  f  mammals/Procyonidae/cacomistle  cacomistle
  f  mammals/Procyonidae/coatimundi  coatimundi
  f  mammals/Procyonidae/raccoon     raccoon
  $ sl debugwalk ..
  f  mammals/Procyonidae/cacomistle  cacomistle
  f  mammals/Procyonidae/coatimundi  coatimundi
  f  mammals/Procyonidae/raccoon     raccoon
  f  mammals/skunk                   ../skunk
  $ cd ..

  $ sl debugwalk ../beans
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ sl debugwalk .
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ sl debugwalk .hg
  abort: path contains illegal component '.hg': mammals/.hg
  [255]
  $ sl debugwalk ../.hg
  abort: path contains illegal component '.hg': .hg
  [255]
  $ cd ..

  $ sl debugwalk -Ibeans
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ sl debugwalk -I '{*,{b,m}*/*}k'
  f  beans/black    beans/black
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk
  $ sl debugwalk -Ibeans mammals
  $ sl debugwalk -Inon-existent
  $ sl debugwalk -Inon-existent -Ibeans/black
  f  beans/black  beans/black
  $ sl debugwalk -Ibeans beans/black
  f  beans/black  beans/black  exact
  $ sl debugwalk -Ibeans/black beans
  f  beans/black  beans/black
  $ sl debugwalk -Xbeans/black beans
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ sl debugwalk -Xbeans/black -Ibeans
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ sl debugwalk -Xbeans/black beans/black
  f  beans/black  beans/black  exact
  $ sl debugwalk -Xbeans/black -Ibeans/black
  $ sl debugwalk -Xbeans beans/black
  f  beans/black  beans/black  exact
  $ sl debugwalk -Xbeans -Ibeans/black
  $ sl debugwalk 'glob:mammals/../beans/b*'
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  $ sl debugwalk '-X*/Procyonidae' mammals
  f  mammals/skunk  mammals/skunk
  $ sl debugwalk path:mammals
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ sl debugwalk ..
  abort: cwd relative path '..' is not under root '$TESTTMP/t'
  (hint: consider using --cwd to change working directory)
  [255]
  $ sl debugwalk beans/../..
  abort: cwd relative path 'beans/../..' is not under root '$TESTTMP/t'
  (hint: consider using --cwd to change working directory)
  [255]
  $ sl debugwalk .hg
  abort: path contains illegal component '.hg': .hg
  [255]
  $ sl debugwalk path:.hg
  abort: path contains illegal component '.hg': .hg
  [255]
  $ sl debugwalk beans/../.hg
  abort: path contains illegal component '.hg': .hg
  [255]
  $ sl debugwalk beans/../.hg/data
  abort: path contains illegal component '.hg': .hg/data
  [255]
  $ sl debugwalk beans/.hg
  abort: path contains illegal component '.hg': beans/.hg
  [255]

Test absolute paths:

  $ sl debugwalk `pwd`/beans
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ sl debugwalk `pwd`/..
  abort: cwd relative path '$TESTTMP/t/..' is not under root '$TESTTMP/t'
  (hint: consider using --cwd to change working directory)
  [255]

Test patterns:

  $ sl debugwalk 'glob:*'
  f  fennel      fennel
  f  fenugreek   fenugreek
  f  fiddlehead  fiddlehead
#if eol-in-paths
  $ echo glob:glob > glob:glob
  $ sl addremove
  adding glob:glob
  warning: filename contains ':', which is reserved on Windows: 'glob:glob' (no-eden !)
  $ sl debugwalk 'glob:*'
  f  fennel      fennel
  f  fenugreek   fenugreek
  f  fiddlehead  fiddlehead
  f  glob:glob   glob:glob
  $ sl debugwalk glob:glob
  glob: $ENOENT$
  $ sl debugwalk glob:glob:glob
  f  glob:glob  glob:glob  exact
  $ sl debugwalk path:glob:glob
  f  glob:glob  glob:glob  exact
  $ rm glob:glob
  $ sl addremove
  removing glob:glob
#endif

  $ sl debugwalk 'glob:**e'
  f  beans/turtle                    beans/turtle
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle

  $ sl debugwalk 're:.*[kb]$'
  f  beans/black    beans/black
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk

Fancy regexes are deprecated but technically supported.
It is okay to delete this test if you are dropping support.
  $ sl debugwalk 're:(?<!fruit)(b)eans/\1lack(?=pinto|$)'
  warning: fancy regexes are deprecated and may stop working (?)
  f  beans/black  beans/black

  $ sl debugwalk path:beans/black
  f  beans/black  beans/black  exact
  $ sl debugwalk path:beans//black
  f  beans/black  beans/black  exact

  $ sl debugwalk relglob:Procyonidae
  $ sl debugwalk 'relglob:Procyonidae/**'
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  $ sl debugwalk 'relglob:Procyonidae/**' fennel
  f  fennel                          fennel                          exact
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  $ sl debugwalk beans 'glob:beans/*'
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ sl debugwalk 'glob:mamm**'
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ sl debugwalk 'glob:mamm**' fennel
  f  fennel                          fennel                          exact
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ sl debugwalk 'glob:j*'
  $ sl debugwalk NOEXIST
  NOEXIST: * (glob)

#if mkfifo no-eden
  $ mkfifo fifo
  $ sl debugwalk fifo
  fifo: unsupported file type (type is fifo)
#endif

  $ rm fenugreek
  $ sl debugwalk fenugreek
  f  fenugreek  fenugreek  exact
  $ sl rm fenugreek
  $ sl debugwalk fenugreek
  f  fenugreek  fenugreek  exact
  $ touch new
  $ sl debugwalk new
  f  new  new  exact

  $ mkdir ignored
  $ touch ignored/file
  $ echo 'ignored' > .gitignore
  $ sl debugwalk ignored
  $ sl debugwalk ignored/file
  f  ignored/file  ignored/file  exact
  $ echo 'ignored/' > .gitignore
  $ sl debugwalk ignored

Test listfile and listfile0

  $ printf 'fenugreek\0new\0' > listfile0
  $ sl debugwalk -I 'listfile0:listfile0'
  f  fenugreek  fenugreek
  f  new        new
  $ printf 'fenugreek\nnew\r\nmammals/skunk\n' > listfile
  $ sl debugwalk -I 'listfile:listfile'
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk
  f  new            new

  $ cd ..
  $ sl debugwalk -R t t/mammals/skunk
  f  mammals/skunk  t/mammals/skunk  exact
  $ mkdir t2
  $ cd t2
  $ sl debugwalk -R ../t ../t/mammals/skunk
  f  mammals/skunk  ../t/mammals/skunk  exact
  $ sl debugwalk --cwd ../t mammals/skunk
  f  mammals/skunk  mammals/skunk  exact

  $ cd ..

Test split patterns on overflow

  $ cd t
  $ echo fennel > overflow.list
  $ sl debugsh -c "for i in range(100): ui.write('x' * 100 + '\n')" >> overflow.list
  $ sl debugsh -c "for i in range(100): ui.write('x' * 100 + '\n')" >> overflow.list
  $ echo fenugreek >> overflow.list
  $ sl debugwalk 'listfile:overflow.list' 2>&1 | egrep -v '^xxx'
  f  fennel     fennel     exact
  f  fenugreek  fenugreek  exact
  $ cd ..

Test empty glob behavior:

  $ cd t
  $ sl debugwalk 'glob:'
  $ sl debugwalk 'relglob:'
  $ cd mammals
  $ sl debugwalk 'glob:'
  $ sl debugwalk 'relglob:'
-I makes glob recursive by default:
  $ sl debugwalk -I 'glob:'
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ cd ..
