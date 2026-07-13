package;

import haxe.DynamicAccess;
import tink.web.spec.OpenApiDocument;

@:asserts
class OpenApiTest {
	public function new() {}

	public function openApiDocument() {
		final json = new OpenApiDocument<OpenApiRoutes>().json();
		final doc:DynamicAccess<Dynamic> = haxe.Json.parse(json);

		asserts.assert(doc['openapi'] == '3.1.0');
		asserts.assert((doc['info'] : Dynamic).title == 'OpenApiRoutes');
		asserts.assert((doc['info'] : Dynamic).version == '0.0.0');
		asserts.assert(!doc.exists('servers'));
		asserts.assert(!doc.exists('tags'));
		asserts.assert(!doc.exists('externalDocs'));

		final paths:DynamicAccess<Dynamic> = doc['paths'];
		asserts.assert(paths.exists('/remove/{id}'));
		asserts.assert(paths.exists('/items'));
		asserts.assert(paths.exists('/nested/ping'));

		final del:Dynamic = Reflect.field(paths['/remove/{id}'], 'delete');
		asserts.assert(del.operationId == 'delete');
		final delParams:Array<Dynamic> = del.parameters;
		asserts.assert(delParams.length == 1);
		asserts.assert(delParams[0].name == 'id');
		asserts.assert(Reflect.field(delParams[0], 'in') == 'path');
		asserts.assert(delParams[0].schema.type == 'integer');

		final post:Dynamic = Reflect.field(paths['/items'], 'post');
		asserts.assert(post.requestBody != null);
		final reqSchema:Dynamic = Reflect.field(Reflect.field(post.requestBody.content, 'application/json'), 'schema');
		asserts.assert(Reflect.hasField(reqSchema, '$$ref'));
		final reqRef:String = Reflect.field(reqSchema, '$$ref');
		asserts.assert(StringTools.startsWith(reqRef, '#/components/schemas/'));
		asserts.assert(reqRef.indexOf('DirectType') == -1);

		final components:Dynamic = doc['components'];
		asserts.assert(components != null);
		asserts.assert(components.schemas != null);
		for (name in Reflect.fields(components.schemas))
			asserts.assert(name.indexOf('DirectType') == -1);

		final ping:Dynamic = Reflect.field(paths['/nested/ping'], 'get');
		asserts.assert(ping.operationId == 'ping');

		return asserts.done();
	}

	public function openApiDocumentOptions() {
		final json = new OpenApiDocument<OpenApiRoutes>({
			info: { title: 'Items API', version: '1.2.3', description: 'Demo API' },
			servers: [{ url: 'https://api.example.com', description: 'Production' }],
			tags: [{ name: 'items', description: 'Item routes' }],
			externalDocs: { url: 'https://docs.example.com', description: 'API guide' },
		}).json();
		final doc:DynamicAccess<Dynamic> = haxe.Json.parse(json);

		asserts.assert((doc['info'] : Dynamic).title == 'Items API');
		asserts.assert((doc['info'] : Dynamic).version == '1.2.3');
		asserts.assert((doc['info'] : Dynamic).description == 'Demo API');

		final servers:Array<Dynamic> = doc['servers'];
		asserts.assert(servers.length == 1);
		asserts.assert(servers[0].url == 'https://api.example.com');
		asserts.assert(servers[0].description == 'Production');

		final tags:Array<Dynamic> = doc['tags'];
		asserts.assert(tags.length == 1);
		asserts.assert(tags[0].name == 'items');
		asserts.assert(tags[0].description == 'Item routes');

		asserts.assert((doc['externalDocs'] : Dynamic).url == 'https://docs.example.com');
		asserts.assert((doc['externalDocs'] : Dynamic).description == 'API guide');

		return asserts.done();
	}
}

class OpenApiRoutes {
	public function new() {}

	@:delete('/remove/$id')
	public function delete(id:Int)
		return {deleted: true};

	@:consumes('application/json')
	@:post('/items')
	public function create(body:CreateRequest):CreateResponse
		return {id: 1, name: body.name};

	@:sub('/nested')
	public function nested()
		return new OpenApiNested();
}

typedef CreateResponse = {
	id:Int,
	name:String
}

typedef CreateRequest = {
	name:String
}

class OpenApiNested {
	public function new() {}

	@:get('/ping')
	public function ping()
		return {ok: true};
}
