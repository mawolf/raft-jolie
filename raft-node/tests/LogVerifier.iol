interface ILogVerifier {
  OneWay:
    shutdown(void)
  RequestResponse:
    status (void) (string),
    stats (void) (string),
    stopVerification (void) (void)
}
