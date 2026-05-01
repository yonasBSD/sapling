#inprocess-hg-incompatible

Test that extensions does not scan CWD when ext.__file__ is a synthetic
"static:..." path from the embedded module finder.

  $ cat > malicious.py << 'EOF'
  > import sys
  > print("MALICIOUS CODE EXECUTED", file=sys.stderr)
  > sys.exit(99)
  > EOF

  $ SAPLING_PYTHON_HOME= sl help non-exit-topic
  abort: no such help topic: non-exit-topic
  (try 'sl help --keyword non-exit-topic')
  [255]
