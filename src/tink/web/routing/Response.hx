package tink.web.routing;

import haxe.io.Bytes;
import tink.http.Response;
import tink.http.Header;

abstract Response(OutgoingResponse) from OutgoingResponse to OutgoingResponse {
  
  @:from static function ofString(s:String):Response 
    return textual('text/plain', s);
  
  @:from static function ofBytes(b:Bytes):Response 
    return binary('application/octetstream', b);
    
  #if tink_template
  @:from static function ofHtml(h:tink.template.Html)
    return textual('text/html', h);
  #end
  
  @:from static function ofUrl(u:tink.Url):Response {
    return new OutgoingResponse(
      new ResponseHeader(
        302,
        'Temporary Redirect',
        [new HeaderField('location', u)]
      ),
      ''
    );
  }

  static public function binary(contentType:String, bytes:Bytes):Response {
    //TODO: calculate ETag
    return OutgoingResponse.blob(bytes, contentType);
  }
    
  static public function textual(contentType:String, string:String):Response
    return binary(contentType, Bytes.ofString(string));
}