package ;

import haxe.unit.*;
import tink.web.*;
import tink.web.routing.Router;

using tink.CoreApi;

//import tink.web.Response;

class Run {
  //@:post 
  //public function upload(body: { foo:String, theFile: UploadedFile } ):Response {
    //return '';
  //}
  
  function new() {}
  static var tests:Array<TestCase> = [
    //new DispatchTest(),
    //new ProxyTest(),
    //new QueryParserTest(),
    //new QueryComposerTest(),
  ];
  static function main() {  
    
    var router = new Router<Session<{ admin: Bool, id:Int }>, Fake>(new Fake());
    
    router.route(null);
    //var router = new Router<{ admin: Bool, id:Int }, Fake>(new Fake());
    
    //router.route(null, 0);
    //var router = new Router<{ admin: Bool, id:Int }, Fake>();
    var r = new TestRunner();
    for (c in tests)
      r.add(c);
      
    if (!r.run())
      Sys.exit(500);
  }

}