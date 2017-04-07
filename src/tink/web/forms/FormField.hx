package tink.web.forms;

import tink.http.StructuredBody;
import tink.http.Request;
import tink.Stringly;

abstract FormField(BodyPart) from BodyPart to BodyPart {
  public function getValue():Stringly 
    return switch this {
      case Value(v): v;
      case File(_): throw 'expected plain value but received file';
    }
    
  @:to function toFloat():Float
    return getValue();
    
  @:to function toInt():Int
    return getValue();    
    
  @:to function toString():String
    return getValue();
    
  @:to public function getFile():FormFile 
    return switch this {
      case Value(_): throw 'expected file but got plain value';
      case File(u): @:privateAccess new FormFile(u);
    }
  
}