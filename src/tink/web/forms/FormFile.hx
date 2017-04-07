package tink.web.forms;

import haxe.io.Bytes;
import tink.io.IdealSource.ByteSource;
import tink.json.Representation;
import tink.http.StructuredBody;
import tink.io.*;
using tink.CoreApi;

typedef JsonFileRep = Representation<{
  mimeType:String,
  fileName:String,
  content:Bytes,
}>;

@:forward
abstract FormFile(UploadedFile) {
  
  inline function new(v) this = v;
  
  @:to function toJson():JsonFileRep {
    var src = this.read();
    return new Representation({
      fileName: this.fileName,
      mimeType: this.mimeType,
      content: switch Std.instance(src, ByteSource) {
        case null: 
          throw new Error(NotImplemented, 'Can only upload files through JSON backed by ByteSources but got a $src');
        case v:
          @:privateAccess v.data;
      }
    });
  }
  
  @:from static function ofJson(rep:JsonFileRep):FormFile {
    var data = rep.get();
    return new FormFile(ofBlob(data.fileName, data.mimeType, data.content));
  }
  
  static inline public function ofBlob(name:String, type:String, data:Bytes):UploadedFile 
    return UploadedFile.ofBlob(name, type, data);
}