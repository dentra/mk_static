library mk_static;

import 'dart:async' show Future;
import 'package:barback/barback.dart';
import 'package:html/dom.dart' show Document;

import 'src/css_processor.dart';
import 'src/js_processor.dart';

/// Finds link tags with rel equals `stylesheet` and href with http(s)
/// and removes them. This eliminates a 404 get on the .css file in
/// absence of internet and speeds up initial loads. Win!
class StaticTansformer extends Transformer {
  final BarbackSettings _settings;
  List<String> _entryPoints;

  StaticTansformer.asPlugin(this._settings) {
    _entryPoints = _readFileList(_settings.configuration['entry_points']);
  }

  @override
  bool isPrimary(AssetId id) {
    if (_entryPoints != null) {
      return _entryPoints.contains(id.path);
    }

    return (id.path.startsWith('web/') || id.path.startsWith('test/')) &&
        id.path.endsWith('.html');
  }

  @override
  Future<dynamic> apply(Transform transform) async {
    // Skip the transform in debug mode.
    if (_settings.mode == BarbackMode.DEBUG) {
      return;
    }

    String html = await transform.primaryInput.readAsString();
    Document document = new Document.html(html);

    AssetId id = transform.primaryInput.id;

    await new InlineCssProcessor(id, transform, document).run();
    await new LinkStylesheetProcessor(id, transform, document).run();
    await new ScriptProcessor(id, transform, document).run();

    transform.addOutput(new Asset.fromString(id, document.outerHtml));
  }

  /// Reads a file list value from the [BarbackSettings]
  /// value - String or List
  static List<String> _readFileList(dynamic /*String or List<String>*/value) {
    if (value == null) {
      return null;
    }

    List<String> files;
    bool error;
    if (value is List<String>) {
      files = value;
      error = value.any((dynamic e) => e is! String);
    } else if (value is String) {
      files = <String>[value];
      error = false;
    } else {
      error = true;
    }

    if (error) {
      print('Bad value for "entry_points" in the css_href_remove transformer. '
          'Expected either one String or a list of Strings.');
    }

    return files;
  }

}
