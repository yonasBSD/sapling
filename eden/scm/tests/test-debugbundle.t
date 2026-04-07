
#require no-eden


Create a test repository:

  $ sl init repo
  $ cd repo
  $ touch a ; sl add a ; sl ci -ma
  $ touch b ; sl add b ; sl ci -mb
  $ touch c ; sl add c ; sl ci -mc
  $ sl bundle --base 'desc(a)' --rev tip bundle.hg -v
  2 changesets found
  uncompressed size of bundle content:
       344 (changelog)
       113  b
       113  c
  $ sl bundle --base 'desc(a)' --rev tip bundle2.hg -v --type none-v2
  2 changesets found
  uncompressed size of bundle content:
       344 (changelog)
       113  b
       113  c

Terse output:

  $ sl debugbundle bundle.hg
  Stream params: {Compression: BZ}
  changegroup -- {nbchanges: 2, version: 02}
      0e067c57feba1a5694ca4844f05588bb1bf82342
      991a3460af53952d10ec8a295d3d2cc2e5fa9690
  b2x:treegroup2 -- {cache: False, category: manifests, version: 1}
      2 data items, 2 history items
      686dbf0aeca417636fa26a9121c681eabbb15a20 
      ae25a31b30b3490a981e7b96a3238cc69583fda1 

Terse output:

  $ sl debugbundle bundle2.hg
  Stream params: {}
  changegroup -- {nbchanges: 2, version: 02}
      0e067c57feba1a5694ca4844f05588bb1bf82342
      991a3460af53952d10ec8a295d3d2cc2e5fa9690
  b2x:treegroup2 -- {cache: False, category: manifests, version: 1}
      2 data items, 2 history items
      686dbf0aeca417636fa26a9121c681eabbb15a20 
      ae25a31b30b3490a981e7b96a3238cc69583fda1 

Verbose output:

  $ sl debugbundle --all bundle.hg
  Stream params: {Compression: BZ}
  changegroup -- {nbchanges: 2, version: 02}
      format: id, p1, p2, cset, delta base, len(delta)
  
      changelog
      0e067c57feba1a5694ca4844f05588bb1bf82342 3903775176ed42b1458a6281db4a0ccf4d9f287a 0000000000000000000000000000000000000000 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 66
      991a3460af53952d10ec8a295d3d2cc2e5fa9690 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 991a3460af53952d10ec8a295d3d2cc2e5fa9690 0000000000000000000000000000000000000000 66
  
      manifest
  
      b
      b80de5d138758541c5f05265ad144ab9fa86d1db 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 0
  
      c
      b80de5d138758541c5f05265ad144ab9fa86d1db 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000 991a3460af53952d10ec8a295d3d2cc2e5fa9690 0000000000000000000000000000000000000000 0
  b2x:treegroup2 -- {cache: False, category: manifests, version: 1}
      2 data items, 2 history items
      686dbf0aeca417636fa26a9121c681eabbb15a20 
      ae25a31b30b3490a981e7b96a3238cc69583fda1 

  $ sl debugbundle --all bundle2.hg
  Stream params: {}
  changegroup -- {nbchanges: 2, version: 02}
      format: id, p1, p2, cset, delta base, len(delta)
  
      changelog
      0e067c57feba1a5694ca4844f05588bb1bf82342 3903775176ed42b1458a6281db4a0ccf4d9f287a 0000000000000000000000000000000000000000 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 66
      991a3460af53952d10ec8a295d3d2cc2e5fa9690 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 991a3460af53952d10ec8a295d3d2cc2e5fa9690 0000000000000000000000000000000000000000 66
  
      manifest
  
      b
      b80de5d138758541c5f05265ad144ab9fa86d1db 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000 0e067c57feba1a5694ca4844f05588bb1bf82342 0000000000000000000000000000000000000000 0
  
      c
      b80de5d138758541c5f05265ad144ab9fa86d1db 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000 991a3460af53952d10ec8a295d3d2cc2e5fa9690 0000000000000000000000000000000000000000 0
  b2x:treegroup2 -- {cache: False, category: manifests, version: 1}
      2 data items, 2 history items
      686dbf0aeca417636fa26a9121c681eabbb15a20 
      ae25a31b30b3490a981e7b96a3238cc69583fda1 

  $ cd ..
