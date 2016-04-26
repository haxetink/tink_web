package tink.web;
import tink.core.Error;

using tink.CoreApi;

@:forward
abstract SubRoute<T:{}>(Surprise<T, Error>) from Surprise<T, Error> to Surprise<T, Error> {
  
  public function route(f:T->Response):Response {
    var ret = this >> f;
    ret.handle(function () { });
    return ret;
  }
  
  @:from static function liftPlain<T:{}>(v:T):SubRoute<T> 
    return liftSync(Success(v));
    
  @:from static function liftSync<T:{}, X>(o:Outcome<T, TypedError<X>>):SubRoute<T>
    return Future.sync(cast o);
    
  @:from static function liftSafe<T:{}>(f:Future<T>):SubRoute<T>
    return f.map(Success);
    
  @:from static function liftPedantic<T:{}, X>(f:Surprise<T, TypedError<X>>):SubRoute<T>
    return cast f;
    
  static public function of<T:{}>(r:SubRoute<T>)
    return r;
}