include "../raft_node.iol"
include "../persistent-state/persistent_state.iol"
include "../volatile-state/volatile_state.iol"
include "../state-machine/state_machine.iol"
include "../utils/debug.iol"

include "math.iol"
include "console.iol"
include "string_utils.iol"

execution{concurrent}

inputPort FollowerInputPort {
  Location: "local"
  Interfaces: IRaftNode, IState, ITimeout, IRaftNodeClient
}

init {
  global.name = "FOLLOWER";

  PersistentState.location -> global.conf.services.persistent_state.location;
  VolatileState.location -> global.conf.services.volatile_state.location;
  DebugLog.location -> global.conf.services.debuglog.location;
  StateMachine.location -> global.conf.services.state_machine.location;

  install ( ChangeState => nullProcess )
}


main {

  [ Initialize (req) (resp) {
    global.conf << req;

    //randomize and calculate timeout value
    random@Math()(randomDouble);
    round@Math((150 + randomDouble * 150 ) { .decimals = 0 } ) (timeout_ms);
    resp.timeout.time = int (timeout_ms);
    resp.timeout.operation = "Timeout";
    resp.success = true;

    log@DebugLog(
      ("Initialize timeout value: " + resp.timeout.time)
      {.service=global.name});

    log@DebugLog(
      ("Initialize (PersistentState: "
        + global.conf.services.persistent_state.location +" ) "
        + "( DebugLog: "+global.conf.services.debuglog.location +" )"
      ) { .service = global.name } )
  } ]

  [ Start () ( status ) {
    status = true;
    nullProcess
  }]

  [ AppendEntries ( req ) ( resp ) {
    resp.term = req.term; // because currentTerm == request.term
    resp.success = true;

    //valueToPrettyString@StringUtils(req)(out);
    //println@Console(out)();

    GetTermFromLog@PersistentState(req.prevLogIndex)(log_term);
    if ( req.prevLogTerm != log_term ) { //log matching property 2
      log@DebugLog(("AppendEntries: log inconsistent") {
        .service = global.name,
        .code = "APPENDENTRIES_LOG_INCONSISTENT",
        .location = NODE_LOCATION,
        .term = req.term } );

      resp.success = false
    }
    else {

      //if not a heart beat
      if ( is_defined (req.entries) ) {
        log@DebugLog(("AppendEntries called with non-empty entries") {
          .service = global.name,
          .code = "APPENDENTRIES_CALLED",
          .location = NODE_LOCATION,
          .term = req.term } );



        //make sure to log registration (persist it)
        log_req.entry.term = req.term;
        index = req.prevLogIndex + 1;
        for ( i = 0, i < #req.entries, i++ ) {
          log_req.index = index+i;
          log_req.entry.command << req.entries[i].command;

          SetLogEntry@PersistentState(log_req)();

          /* cluster configuration is a special case where we need to execute
           * right away and not wait for the commit */
          if (req.entries[i].command.operation == "SetServers") {
            SetServers@StateMachine ( req.entries[i].command.parameter ) ( )
          }

          //AppendToLog@PersistentState(log_entry)()
        }
      };


      //some operations are allowed to be executed
      CommitIndex@VolatileState()(commitIndex);
      if (commitIndex < req.leaderCommit ) {

        LastLogIndex@PersistentState()(stopIndex);
        stopIndex = stopIndex + 1;
        if (stopIndex>req.leaderCommit) {
          stopIndex = req.leaderCommit
        };
        println@Console("commitIndex < req.leaderCommit; stopIndex: " + stopIndex + ", commitIndex: " + commitIndex)();
        GetLogEntries@PersistentState({.from=commitIndex, .to=stopIndex})(entries);

        //valueToPrettyString@StringUtils(entries)(out);
        //println@Console(out)();
        for ( i = 0, i < #entries.entries, i++ ) {
          if ( entries.entries[i].command.operation == "RegisterClient") {
            RegisterClient@StateMachine ( entries.entries[i].command.parameter ) ( answer )
          }
          else if ( entries.entries[i].command.operation == "RegisterStateMachine") {
            RegisterStateMachine@StateMachine ( entries.entries[i].command.parameter ) ( answer )
          }
          else if (entries.entries[i].command.operation == "AddServer" || entries.entries[i].command.operation == "SetServers") {
            nullProcess
          }
          else {
            ClientRequest@StateMachine ( entries.entries[i].command.parameter ) ( answer )
          };
          //println@Console("Updating commitIndex to: " + (commitIndex+1))();
          SetCommitIndex@VolatileState(commitIndex+i+1)()
        }
      }
    }
  } ]

  /**
   * Operation is only called if currentTerm == request.term
   */
  [ RequestVote ( req ) ( resp ) {

    resp.term = req.term; // because currentTerm == request.term

    //did we already vote for someone else this term?
    VotedFor@PersistentState()(votedFor);
    if (votedFor == "" ) { //we did not vote yet
      //accept
      SetVotedFor@PersistentState(req.candidateId)();
      resp.success = true
    }
    else { //we have already voted this term
      //reject
      resp.success = false
    }
  } ]

  [ Shutdown () ( status ) {
    status = true;
    nullProcess
  } ]

  //we have had no append entries or vote requests within the selected time frame
  [ Timeout () () {
    CurrentTerm@PersistentState()(req.term);
    log@DebugLog(("Timeout") {
      .service = global.name,
      .code = "FOLLOWER_TIMEOUT_CALLED",
      .location = NODE_LOCATION,
      .term = req.term } );

    throw (ChangeState,{.changeTo = CANDIDATE })
  }]

  [ ClientRequest ( request ) ( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ ReadRequest ( request ) ( response ) {
    ClientRequest@StateMachine ( request.command ) ( answer );
    if ( answer.success ) {
      response.status = "OK";
      response.response << answer.result
    }
  } ]

  [ RegisterClient () ( response ) {
    log@DebugLog(("RegisterClient called") {
      .service = global.name,
      .code = "REGISTERCLIENT_CALLED",
      .location = NODE_LOCATION } );

     response.status = "NOT_LEADER"
  } ]

  [ RegisterStateMachine ( req ) ( resp ) {
    resp.status = "NOT_LEADER"
  } ]

  [ AddServer ( request )( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ RemoveServer ( request )( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ TransferLeadership ( request ) ( response ) {
    response.status = "NOT_LEADER"
  }]

}
