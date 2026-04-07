#modern-config-incompatible

#require no-eden


  $ configure modern
  $ enable smartlog
  $ newserver master
  $ cat >> .sl/config <<EOF
  > [alias]
  > sl = smartlog -T '{sl}'
  > [templatealias]
  > sl_stablecommit = "{label('sl.stablecommit', smallcommitmeta('arcpull_stable'))}"
  > sl_hash_minlen = 8
  > sl_phase_label = "{ifeq(phase, 'public', 'sl.public', 'sl.draft')}"
  > sl_node = "{label(sl_phase_label, shortest(node, sl_hash_minlen))}"
  > sl = "{label('sl.label', separate('\n', sl_node, sl_stablecommit, '\n'))}"
  > EOF
  $ sl debugsmallcommitmetadata
  Found the following entries:
  $ echo "a" > a ; sl add a ; sl commit -qAm a
  $ echo "b" > b ; sl add b ; sl commit -qAm b
  $ echo "c" > c ; sl add c ; sl commit -qAm c

Add some metadata
  $ sl debugsmallcommitmetadata -r cb9a9f314b8b -c arcpull_stable stable
  $ sl debugsmallcommitmetadata -r d2ae7f538514 -c bcategory bvalue
  $ sl debugsmallcommitmetadata -r 177f92b77385 -c ccategory cvalue
  $ sl debugsmallcommitmetadata
  Found the following entries:
  cb9a9f314b8b arcpull_stable: 'stable'
  d2ae7f538514 bcategory: 'bvalue'
  177f92b77385 ccategory: 'cvalue'

Verify smartlog shows only the configured data
  $ sl debugsmallcommitmetadata
  Found the following entries:
  cb9a9f314b8b arcpull_stable: 'stable'
  d2ae7f538514 bcategory: 'bvalue'
  177f92b77385 ccategory: 'cvalue'
  $ sl sl
  @  177f92b7
  │
  o  d2ae7f53
  │
  o  cb9a9f31
     stable
