include "../raft-node/raft_node.iol"
include "../raft-client/raft_client.iol"

include "console.iol"
include "string_utils.iol"
include "math.iol"

outputPort RaftNode {
  Protocol: sodep
  Interfaces: IRaftNodeClient
}

define print_help {
  println@Console("raftctl <socket://current-raft-cluster-members:port,...> addnode <socket://node-to-add:port>")()
}

define add_node_case {
  println@Console("Connecting to: " + global.conf.nodes.node[0])();
  RaftNode.location = global.conf.nodes.node[0];
  keep_trying = true;
  while (keep_trying) {
    scope (s) {
      install( IOException => node_resp.status = "NOT_OK" );
      AddServer@RaftNode({.newServer = args[2] })(node_resp)
    };
    if ( node_resp.status == "OK" ) {
      println@Console("Node was added to Raft cluster" )();
      keep_trying = false
    }
    else if ( node_resp.status == "NOT_LEADER") {
      println@Console("Not leader")();
      if ( is_defined ( node_resp.leaderHint ) ) {
        RaftNode.location = node_resp.leaderHint
      }
      else {
        random@Math()(random_double);
        node_index = int (random_double*(#global.conf.nodes.node));
        RaftNode.location = global.conf.nodes.node[node_index]
      }
    }
    else {
      println@Console("Failed: " + node_resp.status)();
      keep_trying = false
    }
  }
}

main {
  if ( #args == 0 ) {
    print_help
  }
  else {
    println@Console(args[0])();
    //first argument will always be locations for current raft-cluster
    split_request = args[0];
    split_request.regex = ",";
    split@StringUtils(split_request)(split_response);
    valueToPrettyString@StringUtils(split_response)(out);
    println@Console(out)();
    for ( i = 0, i < #split_response.result, i++ ) {
      global.conf.nodes.node[i] = split_response.result[i]
    };

    //handle the operations
    if ( args[1] == "addnode" ) {
      add_node_case
    } else {
      print_help
    }
  }
}
