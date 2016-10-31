package tink.web;

import tink.CoreApi;

class Session<User> {
  public var getUser(default, null):Void->Promise<Option<User>>;
  
  public function new(getUser) {
    this.getUser = getUser;
  }  
  
  static public var BASIC(default, null):Session<{}> = new Session(function () return Future.sync(Success(None)));
}