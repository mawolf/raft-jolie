include "volatile_state.iol"

inputPort LocalInputPort {
  Location: "local"
  Interfaces: IVolatileState
}

execution {concurrent}

init {
  global.state.commitIndex = 1;
  global.state.lastApplied = 0
}

main {
  [ CommitIndex( ) ( response ) {
      response = global.state.commitIndex
  }]

  [ SetCommitIndex( req ) ( ) {
    global.state.commitIndex = req
  } ]

  [ LastApplied (  ) ( global.state.lastApplied ) { nullProcess } ]

  [ SetLastApplied ( req ) ( ) {
    global.state.lastApplied = req
  } ]
}
