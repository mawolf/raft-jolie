include "raft_node.iol"
include "persistent-state/persistent_state.iol"
include "volatile-state/volatile_state.iol"
include "state-machine/state_machine.iol"
include "utils/debug.iol"

include "runtime.iol"
include "time.iol"
include "console.iol"
include "string_utils.iol"

execution{concurrent}

inputPort NodeInputPort {
  Location: NODE_LOCATION
  Protocol: NODE_PROTOCOL
  Interfaces: IRaftNode, IRaftNodeClient
}

interface ILocalTimeout {
  OneWay:
    Timeout (undefined)
}

inputPort LocalNodeInputPort {
  Location: "local"
  Interfaces: ILocalTimeout
}

outputPort State {
  Location: "local"
  Interfaces: IState, IRaftNode, ITimeout, IRaftNodeClient
}

embedded {
	Jolie:
    "persistent-state/persistent_state.ol" in PersistentState,
    "volatile-state/volatile_state.ol" in VolatileState,
    "state-machine/state_machine.ol" in StateMachine
}

define change_state {
  log@DebugLog(("change_state called with request for change to " + s.ChangeState.changeTo) {.service = global.name});
  //only one state change at the time
  synchronized (state) {
    println@Console("Start")();
    //shut down old state gracefully if running
    if ( State.location != "local" ) {
      Shutdown@State()()
    };

    //dynamically embed the new state
    embedInfo.type = "Jolie";
    embedInfo.filepath = s.ChangeState.changeTo;
    loadEmbeddedService@Runtime( embedInfo )( global.state.location );

    //initialize state with configuration
    Initialize@State(global.conf)(outcome);

    //does state want to be notified on a timeout?
    if ( is_defined (outcome.timeout ) ) {
      global.timeout = outcome.timeout.time;
      global.timeout.operation = "Timeout";
      global.timeout.message.state.location = global.state.location;
      global.timeout.message.timeout = outcome.timeout.time;
      setNextTimeout@Time(global.timeout)
    } else {
      global.timeout = 9999999;
      global.timeout.operation = "Timeout"
    };

    //start state, but handle if state change is requested
    scope ( s ) {
      install( ChangeState => change_state );

      Start@State()()
    };
    println@Console("End")()
	}


}

init {
  global.name = "RAFT-MAIN";

  //make sure changes to location in the State port is global
  State.location -> global.state.location;

  //make sure configuration contains addresses of embedded services
  global.conf.services.persistent_state.location = PersistentState.location;
  global.conf.services.state_machine.location = StateMachine.location;
  global.conf.services.volatile_state.location = VolatileState.location;

  //initialize with addresses of other nodes from command line
  for ( i = 0, i < #args, i++ ) {
    startsWith@StringUtils( args[i] { .prefix = "--log-service="} )( isLogServiceParam );
    //is the parameter --log-service=?
    if ( isLogServiceParam ) { //yes
      split@StringUtils( args[i] { .regex = "="} )(splits);
      global.conf.services.debuglog.location  = splits.result[1];
      DebugLog.location = splits.result[1]
    }
    else {//no, must be an address to another raft node
      global.conf.nodes.(args[i]) = true
    }
  };

  //initialize state machine
  Initialize@StateMachine(global.conf)();
  //was a different debug logger supplied?
  if ( !is_defined ( global.conf.services.debuglog.location ) ) {//no
    //load a local debug logger
    embedInfo.type = "Jolie";
    embedInfo.filepath = "utils/debug.ol";
    loadEmbeddedService@Runtime( embedInfo )( DebugLog.location );
    global.conf.services.debuglog.location = DebugLog.location
  };

  //we start in follower state
  global.state.location = "local";
  s.ChangeState.changeTo = FOLLOWER;
  change_state
}

main {

  [ Timeout ( message ) ] {
    //make sure that we call the correct state
    State.location = message.state.location;

    scope (s) {
      install( ChangeState => change_state );

      Timeout@State()();

      //reset timeout to make sure it will be called again
      timeout = message.timeout;
      timeout.operation = "Timeout";
      timeout.message.state.location = State.location;
      timeout.message.timeout = outcome.timeout.time;
      timeout.message << message;
      setNextTimeout@Time(timeout)
    }
  }

  [ AppendEntries ( entry ) ( response ) {
    setNextTimeout@Time(global.timeout);

    if ( is_defined(req.entries) && #req.entries == 1 && req.entries[0].command.operation == "SetServers" ) {
      //are we already in another cluster?
      Servers@StateMachine()(current_nodes);
      if (current_nodes.count > 0 ) { //yes
        /*We cannot make any changes then. This would result in a potential unsafe
         *state where this node could have two leaders. Requester will be notified
         *with a success=false */
         nullProcess
      }
      else { //no
        SetServers@StateMachine(req.entries[0].command.parameter)();
        s.ChangeState.changeTo = FOLLOWER;
        change_state;
        response.term = currentTerm;
        response.success = true
      }
    };


    CurrentTerm@PersistentState()(currentTerm);
    if ( entry.term < currentTerm ) { //reject
      log@DebugLog(("AppendEntries: entry.term < currentTerm") {.service = global.name});

      response.term = currentTerm;
      response.success = false
    }
    else if ( entry.term > currentTerm ) { //change state
      log@DebugLog(("AppendEntries: entry.term("+entry.term+") > currentTerm("+currentTerm+")") {.service = global.name});

      SetCurrentTerm@PersistentState(entry.term)();

      s.ChangeState.changeTo = FOLLOWER;
      change_state;
      response.term = currentTerm;
      response.success = false
    }
    else { //forward to the actual state
      AppendEntries@State ( entry ) ( response )
    }
  } ]

  [ RequestVote ( vote_request ) ( response ) {

    CurrentTerm@PersistentState()(currentTerm);
    if ( vote_request.term < currentTerm ) { //reject
      log@DebugLog(("RequestVote: vote_request.term("+vote_request.term+") < currentTerm("+currentTerm+")") {.service = global.name});
      response.term = currentTerm;
      response.success = false
    }
    else if ( vote_request.term > currentTerm ) { //change state
      log@DebugLog(("RequestVote: vote_request.term > currentTerm") {.service = global.name});

      SetCurrentTerm@PersistentState(vote_request.term)();
      s.ChangeState.changeTo = FOLLOWER;
      change_state;

      //make sure vote is also given
      RequestVote@State ( vote_request ) ( response )
    }
    else { //forward to the actual state
      RequestVote@State ( vote_request ) ( response )
    }
  } ]

  [ ClientRequest ( request ) ( response ) {
    ClientRequest@State(request)(response)
  } ]

  [ ReadRequest ( request ) ( response ) {
    ReadRequest@State(request)(response)
  } ]

  [ RegisterClient () ( response ) {
    RegisterClient@State()(response)
  } ]

  [ RegisterStateMachine ( filename ) ( resp ) {
    RegisterStateMachine@State ( filename ) ( resp )
  } ]

  [ AddServer ( request )( response ) {
    println@Console("AddServer called in MAIN: " + State.location)();
    AddServer@State ( request ) ( response )
  } ]

  [ RemoveServer ( request )( response ) {
    RemoveServer@State ( request ) ( response )
  } ]

  //used by leadership transfer extension
  [ TimoutNow () () {
    scope (s) {
      install( ChangeState => change_state );
      Timeout@State()()
    }
  }]

  [ TransferLeadership ( request ) ( response ) {
    TransferLeadership@State ( request ) ( response )
  }]
}
