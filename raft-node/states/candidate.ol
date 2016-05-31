include "../raft_node.iol"
include "../persistent-state/persistent_state.iol"
include "../state-machine/state_machine.iol"
include "../utils/debug.iol"
include "console.iol"
include "string_utils.iol"
execution{concurrent}

inputPort CandidateInputPort {
  Location: "local"
  Interfaces: IRaftNode,IState,IRaftNodeClient
}

outputPort OtherRaftNode {
  Protocol: NODE_PROTOCOL
  Interfaces: IRaftNode
}

init {
  global.name = "CANDIDATE";

  PersistentState.location -> global.conf.services.persistent_state.location;
  DebugLog.location -> global.conf.services.debuglog.location;
  StateMachine.location -> global.conf.services.state_machine.location;

  install ( ChangeState => nullProcess )
}

main {

  [ Initialize (req) (resp) {
    global.conf << req;
    resp.success = true;
    log@DebugLog(("Initialize (PersistentState: "
      + global.conf.services.persistent_state.location +" ) "
      + "( DebugLog: "+global.conf.services.debuglog.location+" )") { .service = global.name } )
  } ]

  /**
   * A candidate first votes for himself and then requests votes from others.
   * When this operation is finished it will throw a ChangeState
   */
  [ Start ( ) ( response ) {
    IncrementCurrentTerm@PersistentState()(currentTerm);
    request.term = currentTerm;
    request.candidateId = NODE_LOCATION;

    log@DebugLog(("Starting election for term " + currentTerm) {
      .service = global.name,
      .code = "ELECTION_START",
      .location = NODE_LOCATION,
      .term = request.term } );

    votes = 1;
    Servers@StateMachine()(servers);
    global.conf.nodes << servers.nodes;
    nodes_count = servers.count;

    foreach( node : global.conf.nodes) {
      scope ( s ) {
        install( IOException => nullProcess ); //just proceed to next
        if (node != NODE_LOCATION) {
          OtherRaftNode.location = node;
          RequestVote@OtherRaftNode(request)( vote_answer );
          if ( vote_answer.success ) {

            log@DebugLog(("We received vote from " + node) {
              .service = global.name,
              .code = "ELECTION_START",
              .location = NODE_LOCATION,
              .term = request.term } );

            votes = votes + 1
          }
          else {
            log@DebugLog(("We did not receive vote from " + node) {
              .service = global.name,
              .code = "ELECTION_START",
              .location = NODE_LOCATION,
              .term = request.term } );

            //no reason to go on if some node is having a higher term
            if (vote_answer.term > request.term ) {
              SetCurrentTerm@PersistentState(vote_answer.term)();
              throw ( ChangeState, { .changeTo = FOLLOWER } )
            }
          }
        }
      }
    };

    //did we win?
    if ( votes > (nodes_count/2) ) {
      //send debug log event
      log@DebugLog(("We won the election of term "+request.term+" :)") {
        .service = global.name,
        .code = "ELECTION_WON",
        .location = NODE_LOCATION,
        .term = request.term } );

      throw (ChangeState,{.changeTo = LEADER }) //yes: change to leader
    };

    //no: we didn't win. Change to FOLLOWER and wait
    log@DebugLog(("We lost the election of term "+request.term+" :(") {
      .service = global.name,
      .code = "ELECTION_LOST",
      .location = NODE_LOCATION,
      .term = request.term } );

    throw (ChangeState,{.changeTo = FOLLOWER })
  }]

  [ AppendEntries () () {
    nullProcess
  } ]

  /**
   * Operation is only called if currentTerm == request.term,
   * thus we can reject since we voted to ourself in this term.
   */
  [ RequestVote ( req ) ( resp ) {
    log@DebugLog(("Voting no to " + req.candidateId) { .service = global.name } );

    resp.success = false;
    resp.term = req.term
  } ]

  [ Shutdown () ( status ) {
    log@DebugLog(("Shutting down candidate state") { .service = global.name } );

    status = true;
    exit
  } ]

  [ ClientRequest ( request ) ( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ RegisterClient () ( response ) {
     response.status = "NOT_LEADER"
  } ]

  [ AddServer ( request )( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ RemoveServer ( request )( response ) {
    response.status = "NOT_LEADER"
  } ]

  [ TransferLeadership ( request ) ( response ) {
    response.status = "NOT_LEADER"
  }]

  [ ReadRequest ( request ) ( response ) {
    ClientRequest@StateMachine ( request.command ) ( answer );
    if ( answer.success ) {
      response.status = "OK";
      response.response << answer.result
    }
  } ]

}
