include "debug.iol"

include "console.iol"

execution{concurrent}

inputPort DebugILP {
  Location: "local"
  Interfaces: IDebug
}

main {
  [ log ( msg ) ] {
    println@Console("[" + msg.service + "] " + msg)()
  }
}
