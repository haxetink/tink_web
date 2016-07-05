package tink.web.helpers;

using tink.CoreApi;

abstract Managed<T>(Surprise<T, Error>) from Surprise<T, Error> to Surprise<T, Error> {
  
  public function get() return this;

  @:from static public function ofFuture<T>(f:Future<T>):Managed<T>
    return f.map(Success);
    
  @:from static public function ofOutcome<T>(o:Outcome<T, Error>):Managed<T>
    return Future.sync(o);
    
  @:from static public function ofValue<T>(v:T):Managed<T>
    return ofOutcome(Success(v));
    
  @:from static public function ofError<T>(e:Error):Managed<T>
    return ofOutcome(Failure(e));
}