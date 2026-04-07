
#require no-eden


  $ eagerepo
  $ sl init repo
  $ cd repo
  $ enable sparse
  $ mkdir show hide
  $ echo show-modify-1 > show/modify
  $ echo show-remove-1 > show/remove
  $ echo hide-modify-1 > hide/modify
  $ echo hide-remove-1 > hide/remove
  $ echo show-moveout > show/moveout
  $ echo show-movein > hide/movein
  $ sl add show/modify show/remove hide/modify hide/remove show/moveout hide/movein
  $ sl commit -m "first revision"
  $ echo show-modify-2 > show/modify
  $ echo show-add-2 > show/add ; sl add show/add
  $ sl rm show/remove
  $ echo hide-modify-2 > hide/modify
  $ echo hide-add-2 > hide/add ; sl add hide/add
  $ sl rm hide/remove
  $ sl mv hide/movein show/movein
  $ sl mv show/moveout hide/moveout
  $ sl commit -m "second revision"
  $ sl sparse --exclude hide

Run diff.  This should still show the file contents of excluded files (and should not crash).

  $ sl diff -r ".^" --git
  diff --git a/hide/add b/hide/add
  new file mode 100644
  --- /dev/null
  +++ b/hide/add
  @@ -0,0 +1,1 @@
  +hide-add-2
  diff --git a/hide/modify b/hide/modify
  --- a/hide/modify
  +++ b/hide/modify
  @@ -1,1 +1,1 @@
  -hide-modify-1
  +hide-modify-2
  diff --git a/show/moveout b/hide/moveout
  rename from show/moveout
  rename to hide/moveout
  diff --git a/hide/remove b/hide/remove
  deleted file mode 100644
  --- a/hide/remove
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -hide-remove-1
  diff --git a/show/add b/show/add
  new file mode 100644
  --- /dev/null
  +++ b/show/add
  @@ -0,0 +1,1 @@
  +show-add-2
  diff --git a/show/modify b/show/modify
  --- a/show/modify
  +++ b/show/modify
  @@ -1,1 +1,1 @@
  -show-modify-1
  +show-modify-2
  diff --git a/hide/movein b/show/movein
  rename from hide/movein
  rename to show/movein
  diff --git a/show/remove b/show/remove
  deleted file mode 100644
  --- a/show/remove
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -show-remove-1

Run diff --sparse.  This should only show files within the sparse profile.

  $ sl diff --sparse --git -r ".^"
  diff --git a/show/add b/show/add
  new file mode 100644
  --- /dev/null
  +++ b/show/add
  @@ -0,0 +1,1 @@
  +show-add-2
  diff --git a/show/modify b/show/modify
  --- a/show/modify
  +++ b/show/modify
  @@ -1,1 +1,1 @@
  -show-modify-1
  +show-modify-2
  diff --git a/hide/movein b/show/movein
  copy from hide/movein
  copy to show/movein
  diff --git a/show/moveout b/show/moveout
  deleted file mode 100644
  --- a/show/moveout
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -show-moveout
  diff --git a/show/remove b/show/remove
  deleted file mode 100644
  --- a/show/remove
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -show-remove-1
