package tink.web;

import haxe.io.Bytes;
import tink.http.Response;

abstract Response(OutgoingResponse) from OutgoingResponse to OutgoingResponse {
  
  @:from static function ofString(s:String):Response {
    return make('text/plain', Bytes.ofString(s));
  }
  
  @:from static function ofBytes(b:Bytes):Response {
    return make('application/octetstream', b);
  }
  
  static public function make(contentType:String, bytes:Bytes):Response
    return OutgoingResponse.blob(bytes, contentType);
}