package tink.web;

import tink.CoreApi;
import haxe.ds.Option;

interface Session {
  function getUser():Surprise<Option<{}>, Error>;
}

class BasicSession implements Session {
  
  function new() { }
  
  public function getUser():Surprise<Option<{}>, Error>
    return Future.sync(Success(None));
    
  static public var inst(default, null):BasicSession = new BasicSession();
}