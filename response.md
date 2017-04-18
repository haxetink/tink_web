# Response

## Supported Return Types

The following types and their `Future`/`Promise` variants are supported:

- String
- Http Status Code (using `http-status`)
- Source
- Anything else will be serialized to json or querystring (See below)

## Meta

```haxe
@:produces('TODO')
```