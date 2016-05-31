type LogMsgRequest:string {
  .service?:string
  .term?:long
  .code?:string
  .location?:undefined
}

interface IDebug {
OneWay:
  log ( LogMsgRequest )
}

outputPort DebugLog {
  Location: "local"
  Interfaces: IDebug
  Protocol: sodep
}
