package tink.web.helpers;

import tink.http.StructuredBody;
import tink.http.Request;
import tink.http.StructuredBody;
import tink.web.Stringly;

abstract FormField(BodyPart) from BodyPart to BodyPart {
  public function getValue():Stringly 
    return switch this {
      case Value(v): v;
      case File(_): throw 'expected plain value but received file';
    }
    
  @:to function toString():String
    return getValue();
    
  public function getFile():UploadedFile 
    return switch this {
      case Value(_): throw 'expected file but got plain value';
      case File(u): u;
    }
  
}