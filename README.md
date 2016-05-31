# raft-jolie

[ ] Leader Election
- [X] Correctness Tests
- - [X] Make script to run node instances
- - [X] Make test to make sure more than one node cannot be leader
- - [X] Kill Leader and make sure a new is elected
- [ ] Performance Tests
- - [ ] How fast to elect leader

[ ] Log Replication
- [ ] Implementation
- - [X] Make persistent_state service actually persist data
- - [ ] Load persistent state on run again
- - [X] Persistent Log
- - [X] Recovery
- [ ] Correctness Tests
- - [ ] Is recovered state correct?
- [ ] Performance Tests
- - [ ] How long time does a recovery take?

[ ] Client
- [ ] Implementation
- - [X] RegisterClient
- - [X] RegisterStateMachine
- - [X] ClientRequest
- - [X] Handle seqnum
- [ ] Correctness Tests
- [ ] Performance Tests
- - [ ] How long time does a simple query take?

[ ] Log Compaction
- [ ] Implementation
- - [ ] Simple Jolie solution
- [ ] Correctness Tests
- - [ ] Is recovered state correct?
- [ ] Performance Tests
- - [ ] How fast is recovery?

[ ] Jolie Usage Pattern
- [ ] Implementation
- - [X] Use own state machine
- - [ ] Start nodes
- - [ ] Basket
