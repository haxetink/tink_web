package tink.web;

@:forward
abstract Path(Array<String>) to Array<String> {

  inline function new(a) this = a;
  
  @:to inline public function toString()
    return '/' + this.join('/');
  
}