import 'dart:async' show Future;

import 'package:barback/barback.dart' show Asset, AssetId, Transform;
import 'package:html/dom.dart' show Document, Element;

import 'processor.dart';

/// Удаляем js-ссылки на внешние ресурсы.
class ScriptProcessor extends DocumentProcessor {
  ScriptProcessor(AssetId id, Transform transform, Document document,
    String userAgent) : super(id, transform, document, userAgent);

  @override
  Iterable<Element> query() => document.querySelectorAll('script');

  @override
  bool accept(Element e) => isExternalUrl(e.attributes['src']);

  @override
  String ensureProcess(Element e) {
    String src = e.attributes['src'];
    String mapped = checkMapping(src);
    if (mapped != null) {
      e.attributes['src'] = mapped;
      return null;
    }
    return src;
  }

  @override
  AssetId createElementMapping(String href) {
    return createMapping(href, '.js');
  }

  @override
  Future<String> processExternal(Element e, AssetId assetId, String href) {
    return readExternalUrl(href);
  }

  @override
  void produceOutput(Element e, AssetId jsAssetId, String jsData) {
    e.attributes['src'] = getHref(jsAssetId);
    transform.addOutput(new Asset.fromString(jsAssetId, jsData));
  }
}
