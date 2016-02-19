include "console.iol"
include "time.iol"

include "MonitorNode.iol"

execution { concurrent }

interface LocalTimeoutInterface {
OneWay:
  gather ( undefined )
}

interface MonitorNodeInterface {
RequestResponse:
  getAllStats ( undefined ) ( undefined )
}

outputPort RAFTNodeStatsPort {
Protocol: sodep
Interfaces: StatsInterface
}

inputPort LocalMonitorNodeInput {
Location: "local"
Interfaces: LocalTimeoutInterface
}

inputPort MonitorNodeInput {
Location: "socket://localhost:9000"
Interfaces: MonitorNodeInterface
Protocol: http
}

init
{
  //get RAFT nodes given as parameters
  for (i = 0, i < #args, i++ ) {
    global.servers[i] = args[i];
    println@Console("Monitoring: " + args[i])()
  };
  
  setNextTimeout@Time ( 1000 { .operation = "gather" } )
}

main
{

	[ gather () ] {
		undef( global.leader );
		undef( global.followers );
		undef( global.candidates );

		for (i = 0, i < #global.servers, i++ ) {
			
			        scope( scopeName )
        {
          install( IOException => nullProcess );
        
        	RAFTNodeStatsPort.location = global.servers[i];
			getStats@RAFTNodeStatsPort()(statsResponse);
			


			global.server[i].currentTerm = statsResponse.term;
			global.server[i].name = global.servers[i];

			undef (global.server.(global.servers[i]).raft.Debuglog);
			for ( j = #global.server[i].DebugLog, j < #statsResponse.raft.Debuglog, j++ ) {
				println@Console("SERVER " + global.servers[i] + "-> " +statsResponse.raft.Debuglog[j])();

				global.server[i].DebugLog[j] = statsResponse.raft.Debuglog[j]
			};

			global.server.(global.servers[i]).currentTerm = statsResponse.term;
						

			if ( statsResponse.state == "LEADER" ) {
				global.leader = global.servers[i]
			}
			else if ( statsResponse.state == "FOLLOWER" ) {
				global.followers[#global.followers] = global.servers[i]
			}
			else {
				global.candidates[#global.candidates] = global.servers[i]
			}
         
        }

		

  	};

  	print@Console("Leader: " + global.leader + ". ")();
  	print@Console("Followers: " + #global.followers + ". ")();
  	println@Console("Candidates: " + #global.candidates + ". ")();

  	setNextTimeout@Time ( 1000 { .operation = "gather" } )
	}

	[ getAllStats ( request ) ( response ) {
		for ( i = 0, i < #args, i++ ) {
			response.servers.server[i] = args[i];

			response.server[i] << global.server[i] 
		};

		response.roles.leader = global.leader;

		for ( i = 0, i < #global.followers, i++ ) {
			response.roles.followers.follower[i] = global.followers[i]
		};
		for ( i = 0, i < #global.candidates, i++ ) {
			response.roles.candidates.candidate[i] = global.candidates[i]
		}
	} ]

}
