include "../raft_node.iol"
include "../persistent-state/persistent_state.iol"
include "../volatile-state/volatile_state.iol"
include "../state-machine/state_machine.iol"
include "../utils/debug.iol"

include "console.iol"
include "string_utils.iol"

execution{concurrent}

inputPort CandidateInputPort {
  Location: "local"
  Interfaces: IRaftNode, IState, ITimeout, IRaftNodeClient
}

outputPort OtherRaftNode {
  Protocol: NODE_PROTOCOL
  Interfaces: IRaftNode
}

define update_commit_index {
  nullProcess
}

init {
  global.name = "LEADER";

  PersistentState.location -> global.conf.services.persistent_state.location;
  DebugLog.location -> global.conf.services.debuglog.location;
  StateMachine.location -> global.conf.services.state_machine.location;
  VolatileState.location -> global.conf.services.volatile_state.location;

  install ( ChangeState => nullProcess )
}

main {

  [ Initialize (req) (resp) {
    global.conf << req;


    LastLogIndex@PersistentState()(lastLogIndex);
    foreach ( node : global.conf.nodes ) {
      //the next entry to send to follower i
      global.state.nextIndex.(node) = lastLogIndex + 1;
      //the latest entry that follower i has acknowledged
      global.state.matchIndex.(node) = 0
    };

    resp.timeout.time = 100;
    resp.timeout.operation = "Timeout";
    resp.success = true;
    log@DebugLog(("Initialize (PersistentState: "
      + global.conf.services.persistent_state.location +" ) "
      + "( DebugLog: "+global.conf.services.debuglog.location+" )") { .service = global.name } )
  } ]

  [ Start ( ) ( status ) {
    status = true;
    nullProcess
  }]

  /* if this one is called, it must be bacause there is another leader with same
   * term. This can only happen if there is two disjoint clusters, hence, this
   * is called because of a call to AddServer from another leader, and this node
   * needs to step down  */
  [ AppendEntries ( req ) ( resp ) {
    resp.success = false;
    resp.term = req.term
  } ]

  /**
   * Operation is only called if currentTerm == request.term.
   * We are already leader on this term, so kindly reject vote.
   */
  [ RequestVote () () {
    log@DebugLog(("Voting no to " + req.candidateId) { .service = global.name } );

    resp.success = false;
    resp.term = req.term
  } ]

  [ Shutdown () ( status ) {
    status = true;
    nullProcess
  } ]

  /**
   * Gets called when it is time to send out heart beats
   * to show "dominance".
   */
  [ Timeout () () {
    CurrentTerm@PersistentState()(currentTerm);
    request.term = currentTerm;
    request.leaderId = NODE_LOCATION;
    CommitIndex@VolatileState()(request.leaderCommit);

    GetLogSize@PersistentState()(logSize);

    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;

    nodes_count = servers.count;
    foreach( node : global.conf.nodes) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next
        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;

          //do we have a special case where we are adding a node to cluster?
          if ( !global.conf.nodes.(node) ) {//yes
            /*node is already catching up in rounds, thus, we only need to show
             *send heart beats for dominance */
             request.prevLogIndex = global.state.nextIndex.(node) - 1;
             GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm)
          }
          else {//no, just add entries that the node is missing
            request.prevLogIndex = global.state.nextIndex.(node) - 1;
            GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm);
            if (global.state.nextIndex.(node) > global.state.matchIndex.(node) ) {
              //the entries to send
              log_request.from = global.state.nextIndex.(node);
              LastLogIndex@PersistentState()(log_request.to);
              log_request.to = log_request.to + 1;
              if ( log_request.from < log_request.to ) {
                GetLogEntries@PersistentState(log_request)(out);

                request << out
              }
            }
          };

          //println@Console("prevLogIndex: " + request.prevLogIndex)();
          AppendEntries@OtherRaftNode(request)( answer );
          if ( !answer.success ) { //rejected
            /*no reason to go on if some node is having a higher term, unless node
             *is not really a member of cluster yet */
            if (answer.term > request.term && global.conf.nodes.(node) ) {
              throw ( ChangeState, { .changeTo = FOLLOWER } )
            }
            else { //log inconsistent in FOLLOWER
                if ( global.state.nextIndex.(node) - 1 > 0 ) {
                  global.state.nextIndex.(node) = global.state.nextIndex.(node) - 1
                }
            }
          }
          else {
            global.state.nextIndex.(node) = global.state.nextIndex.(node) + #request.entries
          }
        }
      }
    }
  } ]

  [ ClientRequest ( request ) ( response ) {
    response.status = "NOT_OK";

    //make sure to log registration (persist it)
    CurrentTerm@PersistentState()(log_entry.term);
    log_entry.command.operation = "ClientRequest";
    log_entry.command.parameter << request.command;
    AppendToLog@PersistentState(log_entry)();

    //replicate the log entry
    appendentries_request.term = log_entry.term;
    appendentries_request.leaderId = NODE_LOCATION;
    appendentries_request.entries[0] -> log_entry;
    CommitIndex@VolatileState()(appendentries_request.leaderCommit);

    /*log@DebugLog(
      ("ClientRequest: Starting to send AppendEntries containing the ClientRequest command. Term: " + appendentries_request.term )
      {
        .service = global.name,
        .code = "REQUEST_CLIENT_START",
        .location = NODE_LOCATION,
        .term = appendentries_request.term
      }
    );*/

    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;
    nodes_count = servers.count;

    stop = false;
    successes = 0;
    foreach( node : global.conf.nodes) {
      if ( !stop ) {
    //for ( i = 0, i < #global.conf.nodes.node, i++ ) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next if exception

        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;
          appendentries_request.prevLogIndex = global.state.nextIndex[i] - 1;
          GetTermFromLog@PersistentState(appendentries_request.prevLogIndex)(appendentries_request.prevLogTerm);

          /*log@DebugLog(("ClientRequest: Send AppendEntries to "+OtherRaftNode.location+". Term: " + appendentries_request.term ) {
            .service = global.name,
            .code = "REQUEST_CLIENT_START",
            .location = NODE_LOCATION,
            .term = log_entry.term } );
*/
          AppendEntries@OtherRaftNode(appendentries_request)( answer );
          if (answer.success) {
            global.state.nextIndex[i] = global.state.nextIndex[i] + 1;
            successes++;
            if (successes>nodes_count/2) {
              stop = true
            }

          };
          //no reason to go on if some node is having a higher term
          if (answer.term > appendentries_request.term ) {
            throw ( ChangeState, { .changeTo = FOLLOWER } )
          }
        }
      }
    }
    };

    ClientRequest@StateMachine ( request.command ) ( answer );
    if ( answer.success ) {
      response.status = "OK";
      response.response << answer.result
    };

    SetCommitIndex@VolatileState(appendentries_request.leaderCommit+1)()
  } ]

  [ RegisterClient () ( response ) {
    //randomly generate a client id
    response.clientId = new;
    response.status = "OK";

    //make sure to log registration (persist it)
    CurrentTerm@PersistentState()(log_entry.term);
    log_entry.command.operation = "RegisterClient";
    log_entry.command.parameter = response.clientId;
    AppendToLog@PersistentState(log_entry)();

    //replicate the log entry
    request.term = log_entry.term;
    request.leaderId = NODE_LOCATION;
    request.entries[0] << log_entry;
    CommitIndex@VolatileState()(request.leaderCommit);

    /*log@DebugLog(
      ("RegisterClient: Starting to send AppendEntries containing the RegisterClient command. Term: " + request.term )
      {
        .service = global.name,
        .code = "REGISTER_CLIENT_START",
        .location = NODE_LOCATION,
        .term = request.term
      }
    );*/

    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;
    nodes_count = servers.count;
    foreach( node : global.conf.nodes) {
    //for ( i = 0, i < #global.conf.nodes.node, i++ ) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next if exception
        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;
          request.prevLogIndex = global.state.nextIndex[i] - 1;
          GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm);
          log@DebugLog(("RegisterClient: Send AppendEntries to "+OtherRaftNode.location+". Term: " + request.term ) {
            .service = global.name,
            .code = "REGISTER_CLIENT_START",
            .location = NODE_LOCATION,
            .term = request.term } );

          AppendEntries@OtherRaftNode(request)( answer );
          if (answer.success) {
            global.state.nextIndex[i] = global.state.nextIndex[i] + 1
          };
          //no reason to go on if some node is having a higher term
          if (answer.term > request.term ) {
            throw ( ChangeState, { .changeTo = FOLLOWER } )
          }
        }
      }
    };

    //do the actual execution on the state machine
    RegisterClient@StateMachine (response.clientId) ( );

    SetCommitIndex@VolatileState(request.leaderCommit+1)()

  } ]

  [ RegisterStateMachine ( req ) ( response ) {
    response.status = "NOT_OK";

    //make sure to log registration (persist it)
    CurrentTerm@PersistentState()(log_entry.term);
    log_entry.command.operation = "RegisterStateMachine";
    log_entry.command.parameter = req;
    AppendToLog@PersistentState(log_entry)();

    //replicate the log entry
    request.term = log_entry.term;
    request.leaderId = NODE_LOCATION;
    request.entries[0] << log_entry;
    CommitIndex@VolatileState()(request.leaderCommit);

    log@DebugLog(
      ("RegisterClient: Starting to send AppendEntries containing the RegisterClient command. Term: " + request.term )
      {
        .service = global.name,
        .code = "REGISTER_UDSM_START",
        .location = NODE_LOCATION,
        .term = request.term
      }
    );

    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;
    nodes_count = servers.count;
    foreach( node : global.conf.nodes) {
    //for ( i = 0, i < #global.conf.nodes.node, i++ ) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next if exception

        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;

          request.prevLogIndex = global.state.nextIndex[i] - 1;
          GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm);

          log@DebugLog(("RegisterStateMachine: Send AppendEntries to "+OtherRaftNode.location+". Term: " + request.term ) {
            .service = global.name,
            .code = "REGISTER_UDSM_START",
            .location = NODE_LOCATION,
            .term = request.term } );

          AppendEntries@OtherRaftNode(request)( answer );
          if (answer.success) {
            global.state.nextIndex[i] = global.state.nextIndex[i] + 1
          };
          //no reason to go on if some node is having a higher term
          if (answer.term > request.term ) {
            throw ( ChangeState, { .changeTo = FOLLOWER } )
          }
        }
      }
    };

    SetCommitIndex@VolatileState(request.leaderCommit+1)();

    filename = req;
    RegisterStateMachine@StateMachine ( filename ) ( answer );
    if ( answer ) {
      response.status = "OK"
    }
  } ]

  [ AddServer ( req )( response ) {
    println@Console("AddServer called in leader")();
    response.status = "OK";
    LastLogIndex@PersistentState()(lastLogIndex);
    global.state.nextIndex.(req.newServer) = lastLogIndex + 1;
    global.state.matchIndex.(req.newServer) = 0;

    AddServer@StateMachine(req.newServer)( );

    //make sure to log registration (persistit)
    CurrentTerm@PersistentState()(log_entry.term);
    log_entry.command.operation = "SetServers";
    Servers@StateMachine()(log_entry.command.parameter);

    AppendToLog@PersistentState(log_entry)();

    //replicate the log entry
    request.term = log_entry.term;
    request.leaderId = NODE_LOCATION;
    request.entries[0] << log_entry;
    CommitIndex@VolatileState()(request.leaderCommit);

    log@DebugLog(
      ("AddServer: Starting to send AppendEntries containing the AddServer("+request.newServer+") command. Term: " + request.term )
      {
        .service = global.name,
        .code = "AddServer_START",
        .location = NODE_LOCATION,
        .term = request.term
      }
    );

    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;
    nodes_count = servers.count;
    foreach( node : global.conf.nodes) {
      println@Console("Connecting to node: "+ node)();
    //for ( i = 0, i < #global.conf.nodes.node, i++ ) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next if exception

        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;
          println@Console("watip")();
          request.prevLogIndex = global.state.nextIndex.(node) - 1;
          GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm);
          println@Console("watup")();

          log@DebugLog(("AddServer: Send AppendEntries to "+OtherRaftNode.location+". Term: " + request.term ) {
            .service = global.name,
            .code = "AddServer_SEND_START",
            .location = NODE_LOCATION,
            .term = request.term } );

          valueToPrettyString@StringUtils(request)(out);
          println@Console(out)();
          AppendEntries@OtherRaftNode(request)( answer );
          if (answer.success) {
            global.state.nextIndex[i] = global.state.nextIndex.(node) + 1
          };
          //no reason to go on if some node is having a higher term
          if (answer.term > request.term ) {
            throw ( ChangeState, { .changeTo = FOLLOWER } )
          }
        }
      }
    };

    SetCommitIndex@VolatileState(request.leaderCommit+1)()
  } ]

  [ RemoveServer ( request )( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ TransferLeadership ( request ) ( response ) {
    CurrentTerm@PersistentState()(currentTerm);
    request.term = currentTerm;
    request.leaderId = NODE_LOCATION;
    CommitIndex@VolatileState()(request.leaderCommit);

    GetLogSize@PersistentState()(logSize);

    OtherRaftNode.location = global.conf.nodes.node[i];
    //log_request.from = global.state.nextIndex[i];
    //log_request.to =

    request.prevLogIndex = global.state.nextIndex[i] - 1;
    GetTermFromLog@PersistentState(request.prevLogIndex)(request.prevLogTerm);
    if (global.state.nextIndex[i] > global.state.matchIndex[i] ) {
      //the entries to send
      log_request.from = global.state.nextIndex[i];
      LastLogIndex@PersistentState()(log_request.to);
      log_request.to = log_request.to + 1;
      if ( log_request.from < log_request.to ) {
        GetLogEntries@PersistentState(log_request)(out);

        request << out
      }
      //request.entries << entries
    };


    AppendEntries@OtherRaftNode(request)( answer );
    if ( !answer.success ) { //rejected
      //no reason to go on if some node is having a higher term
      if (answer.term > request.term ) {
        throw ( ChangeState, { .changeTo = FOLLOWER } )
      }
      else { //log inconsistent in FOLLOWER
          if ( global.state.nextIndex[i] - 1 > 0 ) {
            global.state.nextIndex[i] = global.state.nextIndex[i] - 1
          }
      }
    }
    else {
      global.state.nextIndex[i] = global.state.nextIndex[i] + #request.entries
    }
  }]

  [ ReadRequest ( request ) ( response ) {
    ClientRequest@StateMachine ( request.command ) ( answer );
    if ( answer.success ) {
      response.status = "OK";
      response.response << answer.result
    }
  } ]

}
