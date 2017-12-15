# mk_static

A transformer for pub.

Searches all `.html` in `web` and `test` folders and 
eliminates a 404 get on the `.css` and `.js` files in absence of 
internet by transforming `javascript[src]` and 
`link[rel=stylesheet]` remote sources into local ones.

This library is the dev dependency and works 
only for production build mode. 

## Usage
To use, add mk_static to your pubspec:
```yaml
dev_dependencies:
  mk_static: "^1.0.0"
```

Then, add the transformer:
```yaml
transformers:
  - mk_static
```

Also you can point to your files directly:
```yaml
transformers:
  - mk_static:
      entry_points:
        - web/index.html
```

## Bugs/requests

Please report [bugs and feature requests][bugs].

[bugs]: https://github.com/dentra/mk_static/issues
