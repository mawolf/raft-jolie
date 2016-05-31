include "../raft_client.iol"

include "console.iol"

embedded {
	Jolie:
    "../raft_client.ol" in Raft
}
main {

  connect.nodes.node[0] = "socket://localhost:8011";
  connect.nodes.node[1] = "socket://localhost:8009";
  Connect@Raft (connect) (connection_result);
  if ( connection_result ) {
    println@Console("Success!")()
  }
  else {
    println@Console("Failed")()
  }

}
