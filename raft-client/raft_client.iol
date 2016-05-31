include "raft_node.iol"

type ConnectRequest:void {
  .nodes:void {
    .node*:string
  }
}

type ExecuteResponse:void {
  .committed:bool
  .result?:undefined
}

interface IRaftClient {
  RequestResponse:
    Connect (ConnectRequest) (bool),
    RegisterStateMachine (string) (bool),
    Execute (Command) (ExecuteResponse),
    Disconnect (void) (void)
}

outputPort Raft {
  Location: "local"
  Interfaces: IRaftClient
}
