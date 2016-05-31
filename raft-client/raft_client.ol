include "raft_client.iol"
include "raft_node.iol"
include "math.iol"
include "console.iol"

execution{concurrent}

outputPort RaftNode {
  Protocol: sodep
  Interfaces: IRaftNodeClient
}

inputPort LocalInputPort {
  Location: "local"
  Interfaces: IRaftClient
}

define find_minSequenceNum {
  keepGoing = true;
  for ( i = global.client.minSequenceNum, ( i < global.client.sequenceNum ) && keepGoing, i++ ) {
    if ( global.client.status.(i) ) {
      global.client.minSequenceNum = i
    }
    else {
      keepGoing = false
    }
  }
}

main {

  [ Connect ( req ) ( resp ) {
    global.raft << req;

    RaftNode.location = global.raft.nodes.node[0];
    keep_trying = true;
    while (keep_trying) {
      scope (s) {
        install( IOException => node_resp.status = "NOT_OK" );
        RegisterClient@RaftNode()(node_resp)
      };
      if ( node_resp.status == "OK" ) {
        global.leader.location = RaftNode.location;
        keep_trying = false;
        global.client.id = node_resp.clientId;
        global.client.seqnum = 0;
        global.client.minSequenceNum = 0
        //println@Console("Registered with client id: " +  node_resp.clientId )()
      }
      else {
        if ( is_defined ( node_resp.leaderHint ) ) {
          RaftNode.location = node_resp.leaderHint
        }
        else {
          random@Math()(random_double);
          node_index = int (random_double*(#global.raft.nodes.node));
          RaftNode.location = global.raft.nodes.node[node_index]
        }
      }
    };

    resp = true
  } ]

  [ RegisterStateMachine ( filename ) ( resp ) {
    registerStateMachine = filename;
    registerStateMachine.clientId  = global.client.id;

    RaftNode.location = global.leader.location;
    keep_trying = true;
    while (keep_trying) {
      scope (s) {
        install( IOException => node_resp.status = "NOT_OK" );
        RegisterStateMachine@RaftNode(registerStateMachine)(node_resp)
      };
      if ( node_resp.status == "OK" ) {
        keep_trying = false
      }
      else {
        if ( is_defined ( node_resp.leaderHint ) ) {
          RaftNode.location = node_resp.leaderHint
        }
        else {
          random@Math()(random_double);
          node_index = int (random_double*(#global.raft.nodes.node));
          RaftNode.location = global.raft.nodes.node[node_index]
        }
      }
    };
    resp = true
  }]

  [ Execute ( req ) ( resp ) {
    find_minSequenceNum;

//    println@Console("Using client id: "+ global.client.id)();

    RaftNode.location = global.leader.location;
    clientRequest.clientId = global.client.id;
    clientRequest.sequenceNum = global.client.seqnum;
    clientRequest.minSequenceNum = global.client.minSequenceNum;
    clientRequest.command << req;
    ClientRequest@RaftNode(clientRequest)(clientRequest_answer);
    global.client.seqnum = global.client.seqnum + 1;
    resp.result << clientRequest_answer.response;
    resp.committed = true
  } ]

  [ Disconnect ( ) ( ) {
    nullProcess
  } ]
}
