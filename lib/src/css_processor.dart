import 'dart:async' show Future;
import 'dart:typed_data';

import 'package:barback/barback.dart' show Asset, AssetId, Transform;
import 'package:html/dom.dart' show Document, Element;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'processor.dart';

/// Возвращает модифицированный css.
class CssResourceProcessor extends Processor<String, String> {
  static final RegExp pattern1 = new RegExp('@import\\s+[\"\'](http.+?)[\"\']',
      multiLine: true);

  static final RegExp pattern2 = new RegExp('url\\(\\s*(http.+?)\\s*\\)',
      multiLine: true);

  Map<String, AssetId> _hrefMap = <String, AssetId>{};

  CssResourceProcessor(AssetId id, Transform transform, String document,
    String userAgent) : super(id, transform, document, userAgent);

  static bool checkPattern(String text) {
    return text.contains(pattern1) || text.contains(pattern2);
  }

  @override
  Iterable<String> query() {
    _replaceAll(pattern1);
    _replaceAll(pattern2);
    return _hrefMap.keys;
  }

  @override
  bool accept(String e) => true;

  @override
  Future<Null> processOne(String href) async {
    AssetId hrefId = _hrefMap[href];
    addMapping(href, hrefId);
    debug('Downloading css resource: $href');
    if (hrefId.extension == '.css') {
      String data = await http.read(href, headers: headers);
      data = await new CssResourceProcessor(
        hrefId, transform, data, userAgent).run();
      transform.addOutput(new Asset.fromString(hrefId, data));
    } else {
      Uint8List bytes = await http.readBytes(href, headers: headers);
      transform.addOutput(new Asset.fromBytes(hrefId, bytes));
    }
  }

  void _replaceAll(RegExp re) {
    document = document.replaceAllMapped(re, (Match match) {
      String href = match.group(1);
      String mapped = checkMapping(href);
      if (mapped == null) {
        String ext = path.extension(href);
        if (ext.isEmpty) {
          ext = '.css';
        }
        AssetId newAssetId = id.changeExtension('_${_hrefMap.length}$ext');
        _hrefMap[href] = newAssetId;
        mapped = getHref(newAssetId);
      }
      return match.group(0).replaceAll(href, mapped);
    });
  }
}


/// Удаляем css-ссылки на внешние ресурсы из содержимого `style` элементов.
class InlineCssProcessor extends DocumentProcessor {
  InlineCssProcessor(AssetId id, Transform transform, Document document,
    String userAgent) : super(id, transform, document, userAgent);

  @override
  Iterable<Element> query() => document.querySelectorAll('style');

  @override
  bool accept(Element e) => CssResourceProcessor.checkPattern(e.text);

  @override
  String ensureProcess(Element e)  => 'inline';

  @override
  AssetId createElementMapping(String href) {
    return newId('.css');
  }

  @override
  Future<String> processExternal(Element e, AssetId assetId, String href) {
    return new CssResourceProcessor(
      assetId, transform, e.text, userAgent).run();
  }

  @override
  void produceOutput(Element e, AssetId assetId, String newData) {
    e.text = newData;
  }
}

/// Удаляем css-ссылки на внешние ресурсы из тегов `link`.
class LinkStylesheetProcessor extends DocumentProcessor {
  LinkStylesheetProcessor(AssetId id, Transform transform, Document document,
    String userAgent) : super(id, transform, document, userAgent);

  @override
  Iterable<Element> query() => document.querySelectorAll('link[rel=stylesheet]');

  @override
  bool accept(Element e) => isExternalUrl(e.attributes['href']);

  @override
  String ensureProcess(Element e) {
    String href = e.attributes['href'];
    String mapped = checkMapping(href);
    if (mapped != null) {
      e.attributes['href'] = mapped;
      return null;
    }
    return href;
  }

  @override
  AssetId createElementMapping(String href) {
    return createMapping(href, '.css');
  }

  @override
  Future<String> processExternal(Element e, AssetId assetId, String href) async {
    String cssData = await readExternalUrl(href);
    return new CssResourceProcessor(
      assetId, transform, cssData, userAgent).run();
  }

  @override
  void produceOutput(Element e, AssetId assetId, String data) {
    e.attributes['href'] = getHref(assetId);
    transform.addOutput(new Asset.fromString(assetId, data));
  }
}
