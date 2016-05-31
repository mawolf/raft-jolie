include "../utils/debug.iol"
include "LogVerifier.iol"

include "console.iol"
include "string_utils.iol"

execution{concurrent}

inputPort LocalInputPort {
  Location: "socket://localhost:9000"
  Interfaces: IDebug, ILogVerifier
  Protocol: sodep
}

/**
 * There can at most be one leader for each term
 */
define only_one_leader_per_term {
  //is this an election won log event?
  if ( is_defined(entry.code) && entry.code == "ELECTION_WON" ) { //yes
    //do we already have registered a different leader for that term?
    if ( is_defined (global.terms.(entry.term).leader) &&
      !global.terms.(entry.term).leader == entry.location ) {//yes
        //we have a problem
        throw (InconsistentState,"There can only be one leader per term")
      }
    }
    else {//no
      global.terms.(entry.term).leader = entry.location
    }
  }

init {
  global.state = "START";
  global.violations = 0;
  println@Console("Ready.")()
}

main {

  [ log ( entry ) ] {
    if ( global.state != "STOP" ) {
      println@Console("["+entry.location + "] " + entry)();
      only_one_leader_per_term
    }
  }

  [ status ( req ) ( resp ) {
    //make sure no violations and that we actually did get at leader elected
    if ( global.violations == 0 ) {
      resp = "NOT_OK";
      foreach( term : global.terms ) {
        if ( is_defined (global.terms.(term).leader) ) {
          startsWith@StringUtils(global.terms.(term).leader { .prefix="socket://"} )(startsWith);
          if ( startsWith ) {
            resp = "OK"
          }
        }
      }
    }
    else {
      resp = "NOT_OK"
    }
  }]

  [ stats () (resp) {
    valueToPrettyString@StringUtils(global.terms)(resp)
  }]

  [ stopVerification () () {
      global.state = "STOP"
  }]

  [ shutdown () ] {
    exit
  }

}
