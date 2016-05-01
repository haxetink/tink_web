package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import tink.http.Method;
import haxe.ds.Option;

typedef Rule = {
  var pos(default, null):Position;
  var kind(default, null):RuleKind;
  var signature(default, null):Array<RuleArg>;
}

typedef RuleArg = {
  ACapture(name:String, t:Type);
  ABody(t:Type);
  AQuery(t:Type);
  APath;
}

enum RuleKind {
  Calls(calls:Array<Call>);
  Sub(subroutes:Array<SubRoute>);
}

typedef Call = {
  var verb(default, null):Option<Method>;
  var path(default, null):RulePath;
  var rest(default, null):PathRest;
}

enum PathRest {
  None;
  Ignore;
  Capture(name:String);
}

typedef RulePath = Array<PathPart>;

enum PathPart {
  Const(s:String);
  Arg(name:String);
}

typedef SubRoute {
  path:RulePath,
}