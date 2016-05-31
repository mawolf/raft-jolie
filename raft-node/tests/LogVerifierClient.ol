include "../utils/debug.iol"
include "LogVerifier.iol"

include "console.iol"

outputPort LogVerifier {
  Location: "socket://localhost:9000"
  Interfaces: ILogVerifier
  Protocol: sodep
}

main {
  if ( args[0] == "status" ) {
    status@LogVerifier()(status);
    if ( status == "OK" ) {
      println@Console("OK: No violations. Good job!")()
    }
    else {
      println@Console("NOT_OK: There were some violations! :-( You are better than this!")()
    }
  }
  else if ( args[0] == "stop" ) {
    stopVerification@LogVerifier()();
    println@Console("Verification stopped")()
  }
  else if ( args[0] == "stats" ) {
    stats@LogVerifier()(stats);
    println@Console(stats)()
  }
  else if ( args[0] == "shutdown" ) {
    shutdown@LogVerifier();
    println@Console("LogVerifier service is going down!")()
  }
  else {
    println@Console("Parameter must be either \"status\", \"stop\" or \"shutdown\"")()
  }
}
