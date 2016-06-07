package tink.web;

abstract Stringly(String) to String from String { 
  
	@:to public function toUnsafeInt():Null<Int> {
		return Std.parseInt(this);
	}
	
	@:to public function toUnsafeFloat():Null<Float>
		return switch Std.parseFloat(this) {
    case Math.isNaN(_) => true: null;
    case v: v;
  }
	
  @:to public function toInt():Int
    return switch Std.parseInt(this) {
      case null: throw '$this is not a valid integer';
      case v: v;
    }  
    
  @:to public function toFloat():Float
    return switch Std.parseFloat(this) {
      case Math.isNaN(_) => true: throw '$this is not a valid float';
      case v: v;
    }
    
  @:to public function toBool():Bool
    return this != null;
  
  @:from static function ofInt(i:Int):Stringly
    return Std.string(i);
    
  @:from static function ofFloat(f:Float):Stringly
    return Std.string(f);
  
}
