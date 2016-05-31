
type SMClientRequestResponse:void {
  .result?:undefined
  .success:bool
}

type ServersResponse:void {
  .nodes?:undefined
  .count:int
}


interface IStateMachine {
  RequestResponse:
    RegisterClient ( string ) ( void ),
    ClientRequest (Command) (SMClientRequestResponse),
    RegisterStateMachine ( string )( bool ),
    AddServer (string) (void),
    SetServers ( undefined ) ( void ),
    RemoveServer (string) (void),
    Servers ( void ) ( ServersResponse),
    Initialize ( undefined ) ( void )

}

outputPort StateMachine {
  Location: "local"
  Interfaces: IStateMachine
}
