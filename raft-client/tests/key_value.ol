type SetRequest:string {
  .key:string
}
type GetRequest:void {
  .key:string
}
interface IKeyValue {
  RequestResponse:
    Set ( SetRequest ) ( void ),
    Get ( GetRequest ) ( string)
}

inputPort localInputPort {
  Location: "local"
  Interfaces: IKeyValue
}

execution{concurrent}

main {

  [ Set ( req ) () {
    global.store.(req.key).value = req
  }]

  [ Get (req) ( resp ) {
    resp = global.store.(req.key).value
  }]

}
