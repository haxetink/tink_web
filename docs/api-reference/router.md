# Router

The router class is a macro-built class that dispatches HTTP requests to annotated handler methods.

## Methods

### constructor

```haxe
function new(target:Target);
```

### route

```haxe
function route(context:Context):Promise<OutgoingResponse>;
```

#### Arguments

- `context:Context`

#### Returns

- `Promise<OutgoingResponse>`

