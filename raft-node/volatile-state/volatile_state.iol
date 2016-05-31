
interface IVolatileState {
  RequestResponse:
    CommitIndex ( void ) ( long ),
    SetCommitIndex ( int ) ( void ),
    LastApplied ( void ) ( int ),
    SetLastApplied ( int ) ( void )
}

outputPort VolatileState {
  Location: "local"
  Interfaces: IVolatileState
}
