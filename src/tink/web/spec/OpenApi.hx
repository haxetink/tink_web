package tink.web.spec;

import tink.json.schema.Schema;
import tink.json.schema.JsonSchema;

typedef OpenApiInfo = {
	final title:String;
	final version:String;
	final ?description:String;
}

typedef OpenApiExternalDocs = {
	final url:String;
	final ?description:String;
}

typedef OpenApiServer = {
	final url:String;
	final ?description:String;
}

typedef OpenApiTag = {
	final name:String;
	final ?description:String;
	final ?externalDocs:OpenApiExternalDocs;
}

typedef OpenApiParameter = {
	final name:String;
	final place:String;
	final required:Bool;
	final type:String;
}

typedef OpenApiRequestBody = {
	final required:Bool;
	final contentTypes:Array<String>;
	final ?schemaId:String;
}

typedef OpenApiResponse = {
	final status:String;
	final ?contentTypes:Array<String>;
	final ?schemaId:String;
}

typedef OpenApiOperation = {
	final method:String;
	final operationId:String;
	final parameters:Array<OpenApiParameter>;
	final ?requestBody:OpenApiRequestBody;
	final responses:Array<OpenApiResponse>;
}

typedef OpenApiPath = {
	final path:String;
	final operations:Array<OpenApiOperation>;
}

typedef OpenApiSchema = {
	final id:String;
	final schema:Schema;
}

typedef OpenApiDoc = {
	final info:OpenApiInfo;
	final paths:Array<OpenApiPath>;
	final schemas:Array<OpenApiSchema>;
	final ?servers:Array<OpenApiServer>;
	final ?tags:Array<OpenApiTag>;
	final ?externalDocs:OpenApiExternalDocs;
}

class OpenApi {
	// haxe.Json.stringify is not used because some targets (e.g. php) escape '/',
	// which would make the output target-dependent
	static function quote(s:String):String {
		final buf = new StringBuf();
		buf.add('"');
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			switch c {
				case '"'.code: buf.add('\\"');
				case '\\'.code: buf.add('\\\\');
				case '\n'.code: buf.add('\\n');
				case '\r'.code: buf.add('\\r');
				case '\t'.code: buf.add('\\t');
				case 0x08: buf.add('\\b');
				case 0x0C: buf.add('\\f');
				case c if (c < 0x20): buf.add('\\u' + StringTools.hex(c, 4));
				default: buf.addChar(c);
			}
		}
		buf.add('"');
		return buf.toString();
	}

	static function stringify(v:Dynamic):String {
		return switch Type.typeof(v) {
			case TNull: 'null';
			case TBool | TInt | TFloat: Std.string(v);
			case TClass(String): quote(v);
			case TClass(Array): '[${[for (x in (v:Array<Dynamic>)) stringify(x)].join(',')}]';
			default: '{${[for (f in Reflect.fields(v)) '${quote(f)}:${stringify(Reflect.field(v, f))}'].join(',')}}';
		}
	}

	static function rewriteRef(json:String, prefix:String):String {
		// Rewrite JSON Schema $defs pointers to OpenAPI components.schemas
		final from = '"#/$$defs/';
		final to = '"#/components/schemas/$prefix';
		return StringTools.replace(json, from, to);
	}

	static function componentId(prefix:String, id:String):String
		return prefix + id;

	static function mergeComponents(schemas:Array<OpenApiSchema>):Map<String, String> {
		final components = new Map<String, String>();
		final rootBySchemaId = new Map<String, String>();

		for (entry in schemas) {
			final prefix = entry.id + '__';
			for (defId in entry.schema.defs.keys()) {
				final written = rewriteRef(JsonSchema.writeType(entry.schema.defs.get(defId)), prefix);
				components.set(componentId(prefix, defId), written);
			}
			switch entry.schema.root {
				case SRef(id):
					rootBySchemaId.set(entry.id, componentId(prefix, id));
				case other:
					components.set(entry.id, rewriteRef(JsonSchema.writeType(other), prefix));
					rootBySchemaId.set(entry.id, entry.id);
			}
		}

		// Expose each collected schema under its stable macro id as a $ref alias when needed
		for (entry in schemas) {
			final target = rootBySchemaId.get(entry.id);
			if (target != entry.id && !components.exists(entry.id))
				components.set(entry.id, '{"$$ref":${stringify('#/components/schemas/$target')}}');
		}

		return components;
	}

	static function writeParameter(p:OpenApiParameter):String {
		return '{'
			+ '"name":${stringify(p.name)},'
			+ '"in":${stringify(p.place)},'
			+ '"required":${stringify(p.required)},'
			+ '"schema":{"type":${stringify(p.type)}}'
			+ '}';
	}

	static function writeContent(contentTypes:Array<String>, schemaId:Null<String>):String {
		final parts = [for (ct in contentTypes) {
			final schema = schemaId == null
				? '{}'
				: '{"$$ref":${stringify('#/components/schemas/$schemaId')}}';
			'${quote(ct)}:{"schema":$schema}';
		}];
		return '{${parts.join(',')}}';
	}

	static function writeRequestBody(body:OpenApiRequestBody):String {
		return '{'
			+ '"required":${stringify(body.required)},'
			+ '"content":${writeContent(body.contentTypes, body.schemaId)}'
			+ '}';
	}

	static function writeResponse(res:OpenApiResponse):String {
		final parts = ['"description":""'];
		switch res.contentTypes {
			case null | []:
			case types:
				parts.push('"content":${writeContent(types, res.schemaId)}');
		}
		return '{${parts.join(',')}}';
	}

	static function writeOperation(op:OpenApiOperation):String {
		final parts = [
			'"operationId":${stringify(op.operationId)}',
			'"parameters":[${op.parameters.map(writeParameter).join(',')}]',
		];
		if (op.requestBody != null)
			parts.push('"requestBody":${writeRequestBody(op.requestBody)}');

		final responses = [for (r in op.responses)
			'${quote(r.status)}:${writeResponse(r)}'
		];
		parts.push('"responses":{${responses.join(',')}}');
		return '{${parts.join(',')}}';
	}

	static function writePaths(paths:Array<OpenApiPath>):String {
		final byPath = new Map<String, Array<OpenApiOperation>>();
		for (p in paths) {
			final list = byPath.exists(p.path) ? byPath.get(p.path) : [];
			for (op in p.operations) list.push(op);
			byPath.set(p.path, list);
		}
		final keys = [for (k in byPath.keys()) k];
		keys.sort(Reflect.compare);
		final parts = [for (path in keys) {
			final ops = byPath.get(path);
			final methods = [for (op in ops) '${quote(op.method)}:${writeOperation(op)}'];
			'${quote(path)}:{${methods.join(',')}}';
		}];
		return '{${parts.join(',')}}';
	}

	static function writeExternalDocs(docs:OpenApiExternalDocs):String {
		final parts = ['"url":${stringify(docs.url)}'];
		if (docs.description != null)
			parts.push('"description":${stringify(docs.description)}');
		return '{${parts.join(',')}}';
	}

	static function writeServer(server:OpenApiServer):String {
		final parts = ['"url":${stringify(server.url)}'];
		if (server.description != null)
			parts.push('"description":${stringify(server.description)}');
		return '{${parts.join(',')}}';
	}

	static function writeTag(tag:OpenApiTag):String {
		final parts = ['"name":${stringify(tag.name)}'];
		if (tag.description != null)
			parts.push('"description":${stringify(tag.description)}');
		if (tag.externalDocs != null)
			parts.push('"externalDocs":${writeExternalDocs(tag.externalDocs)}');
		return '{${parts.join(',')}}';
	}

	public static function write(doc:OpenApiDoc):String {
		final components = mergeComponents(doc.schemas);
		final ids = [for (id in components.keys()) id];
		ids.sort(Reflect.compare);

		final infoParts = [
			'"title":${stringify(doc.info.title)}',
			'"version":${stringify(doc.info.version)}',
		];
		if (doc.info.description != null)
			infoParts.push('"description":${stringify(doc.info.description)}');

		final parts = [
			'"openapi":"3.1.0"',
			'"info":{${infoParts.join(',')}}',
		];

		switch doc.servers {
			case null | []:
			case servers:
				parts.push('"servers":[${servers.map(writeServer).join(',')}]');
		}

		parts.push('"paths":${writePaths(doc.paths)}');

		if (ids.length > 0) {
			final schemas = [for (id in ids) '${quote(id)}:${components.get(id)}'];
			parts.push('"components":{"schemas":{${schemas.join(',')}}}');
		}

		switch doc.tags {
			case null | []:
			case tags:
				parts.push('"tags":[${tags.map(writeTag).join(',')}]');
		}

		if (doc.externalDocs != null)
			parts.push('"externalDocs":${writeExternalDocs(doc.externalDocs)}');

		return '{${parts.join(',')}}';
	}
}
