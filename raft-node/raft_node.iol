
constants {
  NODE_LOCATION = "socket://localhost:8011",
  NODE_PROTOCOL = sodep,

  FOLLOWER = "states/follower.ol",
  LEADER = "states/leader.ol",
  CANDIDATE = "states/candidate.ol"
}

type LogEntry:void {
  .command:Command
  .term:long
}

type Command:void {
  .operation:string
  .parameter?:undefined
}

type RequestVoteRequest:void {
  .term:long
  .candidateId:string
}

type RequestVoteResponse:void {
  .term:long
  .success:bool
}

type AppendEntriesRequest:void {
  .term:long
  .leaderId:string
  .entries*:LogEntry
  .leaderCommit:long
  .prevLogIndex:long
  .prevLogTerm:long
}

type AppendEntriesResponse:void {
  .term:long
  .success:bool
}

type InitializeResponse:void {
  .success:bool
  .timeout?:void{
    .time:int
    .operation?:string
  }
}

type ClientRequestRequest:void {
  .clientId:string
  .sequenceNum:long
  .minSequenceNum:long
  .command:Command
}

type ClientRequestResponse:void {
  .status:string
  .response?:undefined
  .leaderHint?:any
}

type ClientRegisterResponse:void {
  .status:string
  .clientId?:string
  .leaderHint?:any
}

type RegisterStateMachineResponse:void {
  .status:string
  .leaderHint?:any
}

type RegisterStateMachineRequest:string {
  .clientId:string
}

type AddServerRequest:void {
  .newServer:any
}

type AddServerResponse:void {
  .status:string
  .leaderHint?:any
}

type RemoveServerRequest:void {
  .oldServer:any
}

type RemoveServerResponse:void {
  .status:string
  .leaderHint?:any
}

type TransferLeadershipRequest:void {
  .newLeader:any
}

type TransferLeadershipResponse:void {
  .status:string
  .leaderHint?:any
}

interface ITimeout {
  RequestResponse:
    Timeout (undefined) (undefined) throws ChangeState
}

interface IState {
  RequestResponse:
    Initialize ( undefined ) ( InitializeResponse ),
    Start ( undefined ) ( undefined ) throws ChangeState,
    Shutdown ( undefined ) ( undefined )
}

interface IRaftNode {
  RequestResponse:
    RequestVote ( RequestVoteRequest )( RequestVoteResponse ),
    AppendEntries ( AppendEntriesRequest ) ( AppendEntriesResponse ) throws ChangeState,
    TimoutNow ( void ) ( void )
}

interface IRaftNodeClient {
  RequestResponse:
    ClientRequest ( ClientRequestRequest ) ( ClientRequestResponse ),
    ReadRequest ( ClientRequestRequest ) ( ClientRequestResponse ),
    RegisterClient ( void ) ( ClientRegisterResponse ),
    RegisterStateMachine ( RegisterStateMachineRequest ) ( RegisterStateMachineResponse ),
    AddServer ( AddServerRequest ) ( AddServerResponse ),
    RemoveServer ( RemoveServerRequest ) ( RemoveServerResponse ),
    TransferLeadership ( TransferLeadershipRequest ) ( TransferLeadershipResponse )
}
