package tink.web.routing;

import haxe.io.Bytes;
import httpstatus.HttpStatusCode;
import tink.http.Response;
import tink.http.Header;

using tink.io.Source;

@:forward @:allow(tink.web)
abstract Response(OutgoingResponse) from OutgoingResponse to OutgoingResponse {
  
  @:from static function ofString(s:String):Response 
    return textual('text/plain', s);
  
  @:from static function ofBytes(b:Bytes):Response 
    return binary('application/octet-stream', b);
  
  @:from static function ofRealSource(source:RealSource):Response 
    return new OutgoingResponse(new ResponseHeader(OK, OK, [new HeaderField(CONTENT_TYPE, 'application/octet-stream')]), source.idealize(function(_) return Source.EMPTY));
    
  @:from static function ofIdealSource(source:IdealSource):Response 
    return new OutgoingResponse(new ResponseHeader(OK, OK, [new HeaderField(CONTENT_TYPE, 'application/octet-stream')]), source);
    
  #if tink_template
  @:from static function ofHtml(h:tink.template.Html)
    return textual('text/html', h);
  #end
  
  @:from static function ofUrl(u:tink.Url):Response {
    return new OutgoingResponse(new ResponseHeader(Found, Found, [new HeaderField('location', u)]), Chunk.EMPTY);
  }

  static public function binary(?code, contentType:String, bytes:Bytes, ?headers):Response {
    //TODO: calculate ETag
    return OutgoingResponse.blob(code, bytes, contentType, headers);
  }
  
  static public function empty(?code = OK):Response {
    return new OutgoingResponse(new ResponseHeader(code, code, [new HeaderField(CONTENT_LENGTH, '0')]), Chunk.EMPTY);
  }
    
  static public function textual(?code, contentType:String, string:String, ?headers):Response
    return binary(code, contentType, Bytes.ofString(string), headers);
}
