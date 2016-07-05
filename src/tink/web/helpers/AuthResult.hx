package tink.web.helpers;

import tink.CoreApi;

abstract AuthResult(Lazy<Response>->Response) from Lazy<Response>->Response {
  
  public function respond(l:Lazy<Response>):Response 
    return 
      if (this == null) l.get();
      else this(l.get());
  
  inline function func() return this;
    
  @:from static function ofSurprise(s:Surprise<Noise, Error>):AuthResult 
    return function (l:Lazy<Response>) return s >> function (n:Noise) return l.get();
  
  static public function get<User>(s:Session<User>, f:User->Managed<Bool>) {
    return ofSurprise(s.getUser().flatMap(function (o):Managed<Noise> return switch o {
      case Success(Some(v)): f(v).get() >> function (b:Bool) return if (b) Success(Noise) else Failure(new Error(Forbidden, 'Forbidden'));
      case Success(None): new Error(Unauthorized, 'Unauthorized');
      case Failure(e): e;
    }));
  }
    
  @:op(a && b) static function and(a:AuthResult, b:AuthResult):AuthResult {
    return switch [a, b] {
      case [null, _]: b;
      case [_, null]: a;
      default:
        var a = a.func(),
            b = b.func();
            
        return function (l:Lazy<Response>) return b(a(l));
    }
  }
    
}