include "math.iol"
include "time.iol"
include "console.iol"
include "string_utils.iol"

include "NodeConfiguration.iol"
include "MonitorNode.iol"

execution { concurrent }

constants {
  FOLLOWER = 0,
  CANDIDATE = 1,
  LEADER = 2
}


type RequestVoteRequest:void {
  .term:any
  .candidateId:any
  .lastLogIndex:any
  .lastLogTerm:any
}

//if true, candidate received vote
type RequestVoteResponse:bool {
  .term:any
}

type AppendEntriesRequest:void {
  .term:any
  .leaderId:any
  .prevLogIndex:any
  .prevLogTerm:any
  .entries*:any
  .leaderCommit:any
}

//if true, candidate received vote
type AppendEntriesResponse:bool {
  .term:any
}

interface ElectorServiceInterface {
  RequestResponse:
    election ( undefined ) ( any )
}

interface RAFTInterface {
  OneWay:
    timeout ( undefined ),
    heartbeat ( undefined )
  RequestResponse:
    RequestVote ( RequestVoteRequest ) ( RequestVoteResponse ),
    AppendEntries ( AppendEntriesRequest ) ( AppendEntriesResponse ),
    AddServer ( undefined ) ( undefined ),
    RemoveServer ( undefined ) ( undefined )
}


outputPort Server {
  Interfaces: RAFTInterface
  Protocol: sodep
}

inputPort RAFTInput {
Location: NODE_LOCATION
Protocol: sodep
Interfaces: RAFTInterface, StatsInterface
}

interface TimeoutInterface {
  OneWay:
    timeout ( undefined ),
    heartbeat ( undefined )
}

inputPort LocalRAFTInput {
  Location : "local"
  Interfaces: TimeoutInterface
}

interface LogServiceInterface {
  RequestResponse:
    put ( undefined ) ( undefined )
}

interface DebugLogService {
  OneWay: 
    log ( undefined )
  RequestResponse: 
    getLog(void) (undefined)
}

service DebugLogService {
  Interfaces: DebugLogService
  main
  {
    [log ( entry ) ] {
      global.servers.(entry.server).log[#global.servers.(entry.server).log] = entry;
      println@Console(entry.server + ": " + entry)()
    }

    [ getLog ( req ) ( resp ) {
     resp << global.servers.(entry.server)  
    }]
  }
}

service LogService {
  Interfaces: LogServiceInterface
  main {
    [ put ( entry ) ( resp) {
      global.log[#global.log] = entry;
      resp = true
    } ]
  }
}


init {
  global.state = FOLLOWER;
  global.currentTerm = 0;
  global.votedFor = -1;

  global.logIndex = 0;
  global.logTerm = 0;
  global.lastLogIndex = 0;
  global.lastLogTerm = 0;

  //get other nodes given as parameters
  for (i = 0, i < #args, i++ ) {
    global.servers[i] = args[i];
    println@Console("Adding: " + args[i])()
  };

  //set timeout
  random@Math()(randomDouble);
  round@Math((150 + randomDouble * 150 ) { .decimals = 0 } ) (global.timeout);
  global.timeout = int (global.timeout);
  println@Console("Timeout value: "+global.timeout)();
  setNextTimeout@Time ( global.timeout { .operation = "timeout" } )
}

/*
Any RPC with a newer term causes the recipient to advance its term first.
UpdateTerm(i, j, m) ==
    /\ m.mterm > currentTerm[i]
    /\ currentTerm'    = [currentTerm EXCEPT ![i] = m.mterm]
    /\ state'          = [state       EXCEPT ![i] = Follower]
    /\ votedFor'       = [votedFor    EXCEPT ![i] = Nil]
       \* messages is unchanged so m can be processed further.
    /\ UNCHANGED <<messages, candidateVars, leaderVars, logVars>>
*/
define updateTerm
{
  synchronized( state ) {
    if ( req.term > global.currentTerm ) {
      log@DebugLogService(("updateTerm: req.term (" + req.term + ") > currentTerm (" + global.currentTerm + "), update term " ) { .server = NODE_LOCATION } );
      global.state = FOLLOWER;
      global.currentTerm = req.term;
      global.votedFor = -1
   }
  }
}

define sendHeartBeats
{
  for ( i = 0, i < #global.servers, i++ ) {
    scope( scopeName )
    {
      install( IOException => log@DebugLogService(("sendHeartBeats: IOException to " + global.servers[i] ) { .server = NODE_LOCATION } ) );
    
      if ( global.servers[i] != NODE_LOCATION ) {
        Server.location = global.servers[i];
        with (appendEntriesReq) {
          .term = global.currentTerm;
          .leaderId = NODE_LOCATION;
          .prevLogIndex = global.lastLogIndex;
          .prevLogTerm = global.lastLogIndex;
          .leaderCommit = void
        };
       // log@DebugLogService("heartbeat: sending to server " + global.servers[i] { .server = NODE_LOCATION } );
        AppendEntries @ Server (appendEntriesReq) (appendEntriesResp);
        if ( appendEntriesResp.term > global.currentTerm) {
          synchronized( state ){
            global.currentTerm = appendEntriesResp.term;
            global.state = FOLLOWER;
            global.votedFor = -1;
            setNextTimeout@Time ( global.timeout { .operation = "timeout" } );
            i = #global.servers
          }
        }
      }
    }
  };

  if ( global.state == LEADER ) {
    setNextTimeout@Time ( 100 { .operation = "heartbeat" } )
  }
    
}
main {

  [ heartbeat () ] {
    //TODO: we need to resend (retry) at every heartbeat
    sendHeartBeats
  }

  [ timeout () ] {
    synchronized( state ){
      global.currentTerm = global.currentTerm + 1;
      global.state = CANDIDATE;      
      global.votedFor = NODE_LOCATION;

      requestVoteReq.conf.term = global.currentTerm;
      requestVoteReq.conf.candidateId = NODE_LOCATION;
      requestVoteReq.conf.lastLogIndex = global.lastLogIndex;
      requestVoteReq.conf.lastLogTerm = global.lastLogTerm
    };

    log@DebugLogService(("timeout: Changed state to CANDIDATE, and incremented global.currentTerm to " + global.currentTerm ) { .server = NODE_LOCATION } );
    for ( i = 0, i < #global.servers, i++ ) {
      requestVoteReq.servers[i] = global.servers[i]
    };


    voteCount = 1;

    //TODO: make concurrent
    for ( i = 0, i < #global.servers, i++ ) {
      scope( scopeName )
      {

        install( IOException => println@Console(Server.location + " connection refused. Node probably down.")() );
      
        if ( global.servers[i] != NODE_LOCATION) {
          Server.location = global.servers[i];
          RequestVote @ Server (requestVoteReq.conf) (requestVoteResp);
          if ( requestVoteResp && requestVoteResp.term == requestVoteReq.conf.term ) {
            voteCount = voteCount + 1;
            log@DebugLogService(("Got vote from " + requestVoteReq.servers[i]) { .server = NODE_LOCATION } )
          }
          else {
            log@DebugLogService(("Did not get vote from " + requestVoteReq.servers[i]) { .server = NODE_LOCATION } )
          }
        }
      }
    };

    log@DebugLogService(("election: Votes " + voteCount + " out of " + #global.servers ) { .server = NODE_LOCATION } );

    synchronized( state ){
      if ( global.state == CANDIDATE ) {
        // if having the majority of votes, we are now leader
        if ( voteCount > (#global.servers/2) || #global.servers == 0 ) {
          log@DebugLogService(("timeout: candidate won. Setting state LEADER and start sending heartbeats, term " + global.currentTerm ) { .server = NODE_LOCATION } );
          global.state = LEADER;
          sendHeartBeats
        }
        else { //did not get majority or split vote, another must be leader or re-election
          log@DebugLogService("timeout: candidate did not win. Setting state FOLLOWER and resetting timeout" { .server = NODE_LOCATION } );
          global.state = FOLLOWER;
          global.votedFor = -1;
          setNextTimeout@Time ( global.timeout { .operation = "timeout" } )
        }
      }
    }
  } 

  /*  .term:any
      .leaderId:any
      .prevLogIndex:any
      .prevLogTerm:any
      .entries*:any
      .leaderCommit:any*/
  [ AppendEntries ( req ) ( resp ) {
    debugreq << req;


    updateTerm; /* Notice: if req.term was larger than global.currentTerm, then they now would be 
                   equal now because of updateTerm */

    /* always give currentTerm to requester */
    resp.term = global.currentTerm;

    if (global.state == FOLLOWER ) {
      //reset timeout
      setNextTimeout@Time ( global.timeout { .operation = "timeout" } )
    };

    /* Reject, requester not updated enough */
    if ( req.term < global.currentTerm ) {
      resp = false
    };

    if ( req.term == global.currentTerm && global.state == CANDIDATE ) {
      global.state = FOLLOWER
    };
    
    if ( req.term == global.currentTerm && global.state == FOLLOWER ) {
      resp = true
    };

    if ( req.term == global.currentTerm && global.state == LEADER ) {
      log@DebugLogService(("DET SEJLER TOTALT! " + global.currentTerm ) { .server = NODE_LOCATION } );
      valueToPrettyString@StringUtils(debugreq) (debugstring1);
      log@DebugLogService(("1 -> " + debugstring1 ) { .server = NODE_LOCATION } );
      valueToPrettyString@StringUtils(global) (debugstring2);
      log@DebugLogService(("2 -> " + debugstring2 ) { .server = NODE_LOCATION } )
    }
  
  }]

  //term, candicateId, lastLogIndex , lastLogTerm
  [ RequestVote ( req ) ( resp ) {
    updateTerm;

    if ( global.state != LEADER ) {
      setNextTimeout@Time ( global.timeout { .operation = "timeout" } )
    };

    if ( req.term == global.currentTerm && ( global.votedFor == -1 || global.votedFor == req.candidateId ) ) {
      global.votedFor = req.candidateId;
      resp = true;
      log@DebugLogService(("RequestVote: voted yes to " + req.candidateId + " with term " + req.term ) { .server = NODE_LOCATION } )
    }
    else {
      log@DebugLogService(("RequestVote: voted no to " + req.candidateId ) { .server = NODE_LOCATION } );
      resp = false
    };
    resp.term = global.currentTerm
  } ]

  [ getStats() (resp) {
    if ( global.state == LEADER ) { resp.state = "LEADER" };
    if ( global.state == FOLLOWER ) { resp.state = "FOLLOWER" };
    if ( global.state == CANDIDATE ) { resp.state = "CANDIDATE" };

    resp.term = global.currentTerm;
    getLog@DebugLogService()();

    for (i = 0, i < #global.RaftLog, i++ ) {
      resp.raft.Debuglog[i] = global.RaftLog[i]
    }
  } ]
}


