
include "../raft_node.iol"
include "persistent_state.iol"

include "file.iol"
include "string_utils.iol"
include "console.iol"

execution{sequential}

inputPort PersistentStateLIP {
  Location: "local"
  Interfaces: IPersistentState
}

define save_complete_state {
  replaceAll@StringUtils( NODE_LOCATION { .replacement = "", .regex = "socket://" } )(location);
  writeFileRequest.content -> global.state;
  writeFileRequest.filename = "." + location + ".state";
  writeFileRequest.format = "json";
  writeFile@File( writeFileRequest )( )
}

define append_to_log {
  replaceAll@StringUtils( NODE_LOCATION { .replacement = "", .regex = "socket://" } )(location);
  writeFileRequest.content -> entry;
  writeFileRequest.append = 1;
  writeFileRequest.filename = "." + location + ".log";
  writeFileRequest.format = "json";
  writeFile@File( writeFileRequest )( );

  //add new line
  undef(writeFileRequest.format);
  writeFileRequest.content = "\n";
  writeFileRequest.append = 1;
  writeFileRequest.filename = "." + location + ".log";
  writeFile@File( writeFileRequest )( )
}

init {
    global.state.currentTerm = long(0);
    global.state.votedFor = "";

    global.log.entry[0].term = 0;
    global.log.entry[0].command.operation = "NOP"
}

main {

  [ CurrentTerm ( ) ( global.state.currentTerm ) { nullProcess } ]

  [ SetCurrentTerm ( term ) ( ) {
    global.state.currentTerm = term;
    //reset voted for
    global.state.votedFor = "";

    save_complete_state
  } ]

  [ IncrementCurrentTerm ( ) ( newCurrentTerm ) {
    global.state.currentTerm = global.state.currentTerm + 1;
    newCurrentTerm = global.state.currentTerm;

    //reset voted for: we are in a new term
    global.state.votedFor = "";

    save_complete_state
  } ]

  [ VotedFor ( ) ( global.state.votedFor ) { nullProcess } ]

  [ SetVotedFor ( votedFor ) ( ) {
    global.state.votedFor = votedFor;

    save_complete_state
  } ]

  [ AppendToLog ( entry ) ( ) {
    global.log.entry[#global.log.entry] << entry;
    append_to_log
  }]

  [ SetLogEntry ( req ) ( ) {
    global.log.entry[req.index] << req.entry
  }]

  [ LastLogIndex () ( response ) {
    response = #global.log.entry - 1
  }]

  [ GetTermFromLog ( index ) ( term ) {
    if (index >= #global.log.entry) {
      term = global.log.entry[index].term
    }
    else {
      term = 0
    }
  } ]

  [ GetLogEntries ( request ) ( response ) {
    j = 0;
    for ( i = request.from, i < request.to && i < #global.log.entry, i++ ) {
      response.entries[j] << global.log.entry[i];
      j = j + 1
    }
  }]

  [ GetLogSize ( ) ( response ) {
    response = #global.log.entry
  }]

}
