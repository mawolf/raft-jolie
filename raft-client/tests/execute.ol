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
	if ( !connection_result ) {
    println@Console("Failed")()
  }
  else {
    RegisterStateMachine@Raft ("../raft-client/tests/key_value.ol") (registration_result);
    if ( registration_result ) {

			command.operation = "Set";
			command.parameter << "teststring" {.key="var"};
			Execute@Raft (command)( execution_result );
			if ( execution_result.committed ) {
				command.operation = "Get";
				undef(command.parameter);
				command.parameter.key="var";
				Execute@Raft (command)( execution_result );
				if ( execution_result.committed && execution_result.result == "teststring" ) {
					println@Console("Success!")()
				}
				else {
					println@Console("Failed 3")()
				}
			}
			else {
				println@Console("Failed 2")()
			}
    }
    else {
      println@Console("Failed 1")()
    }
	}

}
