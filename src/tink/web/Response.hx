package tink.web;

import haxe.io.Bytes;
import tink.http.Response;
import tink.template.Html;

using tink.CoreApi;

typedef ResponseRep = Surprise<OutgoingResponse, Error>;

@:forward
abstract Response(ResponseRep) from ResponseRep to ResponseRep {
  
  @:from static function flatten(f:Future<Response>):Response 
    return (f : Future<ResponseRep>).flatten();
    
  public function handleError(f:Error->OutgoingResponse):Future<OutgoingResponse>
    return this.map(function (o) return switch o {
      case Success(res): res;
      case Failure(e): f(e);
    });
  
  @:from static function ofResponse(o:OutgoingResponse):Response
    return ofSync(Success(o));
  
  @:from static function ofFutureResponse(o:Future<OutgoingResponse>):Response
    return o.map(function(res) return Success(res));
    
  @:from static function ofError(e:Error):Response
    return ofSync(Failure(e));
    
  @:from static function ofSync(o:Outcome<OutgoingResponse, Error>):Response
    return Future.sync(o);
  
  @:noCompletion public inline function toFuture() return this;
  
  @:from static function text(s:String):Response
    return ofResponse(s);
    
  @:from static function html(s:Html):Response
    return ofResponse(OutgoingResponse.blob(Bytes.ofString(s), 'text/html'));
    
  @:from static function unsafeHtml(s:Surprise<Html, Error>):Response
    return s.map(function (o) return o.map(function (html) return OutgoingResponse.blob(Bytes.ofString(html), 'text/html')));
    
  //@:from static function unsafeResponse(s:Surprise<OutgoingResponse, Error>):Response
    //return s.map(function (o):OutgoingResponse return switch o {
      //case Failure(e): e;
      //case Success(o): o;
    //});
    
}