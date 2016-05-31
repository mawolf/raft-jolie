type GetLogEntriesRequest:void {
  .from:long
  .to:long
}

type GetLogEntriesResponse:void {
  .entries*:LogEntry
}

type SetLogEntryRequest:void {
  .index:long
  .entry:LogEntry
}

interface IPersistentState {
  RequestResponse:
    CurrentTerm ( void ) ( long ),
    SetCurrentTerm ( long ) ( void ),
    IncrementCurrentTerm ( void ) ( long ),
    VotedFor ( void ) ( string ),
    SetVotedFor ( string ) ( void ),
    AppendToLog ( LogEntry ) ( void ),
    SetLogEntry ( SetLogEntryRequest ) ( void ),
    LastLogIndex ( void ) ( long ),
    GetTermFromLog ( long ) ( long ),
    GetLogEntries ( GetLogEntriesRequest ) ( GetLogEntriesResponse ),
    GetLogSize ( void ) ( long )
}

outputPort PersistentState {
  Location: "local"
  Interfaces: IPersistentState
}
