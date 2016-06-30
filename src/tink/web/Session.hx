package tink.web;

import tink.CoreApi;
import haxe.ds.Option;

interface Session<User> {
  function getUser():Surprise<Option<User>, Error>;
}

class BasicSession<User> implements Session<User> {
  function new() { }
  public function getUser():Surprise<Option<User>, Error>
    return Future.sync(Success(None));
  static public var inst(default, null):Session<{}> = new BasicSession();
}