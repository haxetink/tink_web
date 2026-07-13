# OpenApiDocument

Generates an [OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0) document from route type metadata. JSON request/response bodies use schemas from `tink_json`.

Usage:

```haxe
var spec = new OpenApiDocument<MyRoutes>({
  info: { title: 'My API', version: '1.2.3', description: '...' },
  servers: [{ url: 'https://api.example.com' }],
  tags: [{ name: 'items', description: 'Item routes' }],
  externalDocs: { url: 'https://docs.example.com', description: 'API guide' },
}).json();
```

The constructor argument is optional. When omitted, `info.title` defaults to the route type name and `info.version` to `"0.0.0"`; `servers`, `tags`, and `externalDocs` are omitted from the document.

## Limitations

The generator covers paths, methods, parameters, JSON bodies, and content types. The following route metadata is **not** exported yet.

| Route metadata | Runtime behavior | OpenAPI equivalent (not generated) |
| --- | --- | --- |
| `@:restrict(...)` | Requires a logged-in user; returns `401` or `403` | `security`, `components.securitySchemes`, `401`/`403` responses |
| `@:header(name, value)` | Adds fixed response headers | `responses.<status>.headers` |
| `@:statusCode(n)` | Sets the success status (e.g. `201`, `307`) | Only that status is listed; redirect `Location`, empty `Noise`, and error statuses are omitted |
| `@:produces` / `@:consumes` mismatch | Returns `406 Not Acceptable` | `406` response |
| `@:html(fn)` | Renders `text/html` from the handler result | `content.text/html` alongside JSON |
| `RealStream<T>` | Server-Sent Events (`text/event-stream`) | `content.text/event-stream` with a schema for `T` |
| `FormFile`, `RealSource`, `Bytes`, … | Raw or multipart bodies | `multipart/form-data` or `format: binary` schemas |
| Interface return types | Serialized at runtime | `oneOf` or a generic object schema |
| Doc comments, `@:sub` groups | Documentation / grouping | Operation `summary`, `description`, and per-operation `tags` (document-level `tags` / `externalDocs` can be passed to the constructor) |

For API Gateway or similar tooling, import the generated spec as-is for path/method/schema coverage, then add auth and extra responses manually where needed.
