package tink.web;

import haxe.io.Bytes;
import tink.http.Response;
import tink.template.Html;

using tink.CoreApi;

abstract Response(Future<OutgoingResponse>) from Future<OutgoingResponse> to Future<OutgoingResponse> {
  
  @:from static function flatten(f:Future<Response>):Response 
    return (f : Future<Future<OutgoingResponse>>).flatten();
  
  @:from static function ofSync(res:OutgoingResponse):Response
    return Future.sync(res);
  
  @:noCompletion public inline function toFuture() return this;
  
  @:from static function text(s:String):Response
    return ofSync(s);
    
  @:from static function html(s:Html):Response
    return ofSync(OutgoingResponse.blob(Bytes.ofString(s), 'text/html'));
    
  @:from static function unsafeHtml(s:Surprise<Html, Error>):Response
    return s.map(function (o):OutgoingResponse return switch o {
      case Failure(e): e;
      case Success(html): OutgoingResponse.blob(Bytes.ofString(html), 'text/html');
    });
    
  @:from static function ofError(e:Error):Response
    return ofSync(e);
    
  @:from static function unsafeResponse(s:Surprise<OutgoingResponse, Error>):Response
    return s.map(function (o):OutgoingResponse return switch o {
      case Failure(e): e;
      case Success(o): o;
    });
    
}