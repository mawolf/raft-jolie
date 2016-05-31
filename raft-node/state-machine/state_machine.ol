include "raft_node.iol"
include "state_machine.iol"
include "ports_utils.iol"
include "runtime.iol"
include "reflection.iol"
include "console.iol"
include "time.iol"

execution{sequential}

inputPort LocalInputPort {
  Location: "local"
  Interfaces: IStateMachine
}

define update_seqnums {
  foreach ( seqnum : global.clients.(request.clientId).seq ) {
    if ( seqnum < request.minSequenceNum) {
      undef(global.clients.(request.clientId).seq.(seqnum))
    }
  };
  global.clients.(id) = request.minSequenceNum
}

define remove_old_sessions {
  getCurrentTimeMillis@Time()(currentTime);
  hourAgo = currentTime - 3600000; //minus 1 hour
  foreach ( sid : global.clients ) {
    if ( global.clients.(sid).timestamp < hourAgo ) {
      undef(global.clients.(sid))
    }
  }
}

main {

  [ Initialize ( request ) () {
    //println@Console("StateMachine: Initialize" )();
    global.conf << request;
    global.state.node_count = 0;
    foreach ( node : global.conf.nodes )  {
      global.state.node_count = global.state.node_count + 1
    }

  }]

  [ RegisterClient ( id ) ( ) {
    //println@Console("StateMachine: RegisterClient " )();
    global.clients.(id) = 0;
    getCurrentTimeMillis@Time()(global.clients.(id).timestamp)
  }]

  [ ClientRequest ( request ) ( response ) {
    update_seqnums;
    remove_old_sessions;

    //exactly once
    if ( is_defined ( global.clients.(request.clientId).(sequenceNum) ) ) {
      response.result << global.clients.(request.clientId).(sequenceNum);
      response.success = true
    }
    else {
      UDSM.location = global.ports.UDSM.location;
      if ( is_defined (UDSM) ) {
        //println@Console("RUNNING: " + request.operation )();
        invoke.outputPort = "UDSM";
        invoke.operation = request.operation;
        invoke.data << request.parameter;
        invoke@Reflection(invoke)( response.result );
        global.clients.(request.clientId).seq.(sequenceNum) << response.result;

        //update timestamp
        getCurrentTimeMillis@Time()(global.clients.(id).timestamp);
        response.success = true
      }
      else {
        throw (StateMachineNotRegistered)
      }
    }
  }]

  [ RegisterStateMachine ( request ) ( response ) {
    //println@Console("StateMachine: RegisterStateMachine " )();
    createOutputFromInput@PortsUtils({.filename = request})();
    embedInfo.type = "Jolie";
    embedInfo.filepath = request;
    loadEmbeddedService@Runtime( embedInfo )( UDSM.location );
    global.ports.UDSM.location = UDSM.location;

    response = true
  }]

  [ AddServer ( request ) () {
    global.conf.nodes.(request) = true;
    global.state.node_count = global.state.node_count + 1
  }]

  [ RemoveServer ( request ) () {
    undef(global.conf.nodes.(request));
    global.state.node_count = global.state.node_count - 1
  }]

  [ Servers () (response) {
    response.nodes << global.conf.nodes;
    response.count = global.state.node_count
  }]

  [ SetServers ( request ) () {
    undef(global.conf.nodes);
    count = 0;
    foreach(node : request) {
      global.conf.nodes.(node) = true;
      count = count + 1
    };
    global.state.node_count = count
  }]

}
