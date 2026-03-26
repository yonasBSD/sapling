
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# test sparse

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init myrepo
  $ cd myrepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > sparse=
  > rebase=
  > EOF

  $ echo a > index.html
  $ echo x > data.py
  $ echo z > readme.txt
  $ cat > base.sparse << 'EOF'
  > [include]
  > *.sparse
  > EOF
  $ sl ci -Aqm initial
  $ cat > webpage.sparse << 'EOF'
  > %include base.sparse
  > [include]
  > *.html
  > EOF
  $ sl ci -Aqm initial

# Clear rules when there are includes

  $ sl sparse --include '*.py'
  $ ls
  data.py
  $ sl sparse --clear-rules
  $ ls
  base.sparse
  data.py
  index.html
  readme.txt
  webpage.sparse

# Clear rules when there are excludes

  $ sl sparse --exclude '*.sparse'
  $ ls
  data.py
  index.html
  readme.txt
  $ sl sparse --clear-rules
  $ ls
  base.sparse
  data.py
  index.html
  readme.txt
  webpage.sparse

# Clearing rules should not alter profiles

  $ sl sparse --enable-profile webpage.sparse
  $ ls
  base.sparse
  index.html
  webpage.sparse
  $ sl sparse --include '*.py'
  $ ls
  base.sparse
  data.py
  index.html
  webpage.sparse
  $ sl sparse --clear-rules
  $ ls
  base.sparse
  index.html
  webpage.sparse
