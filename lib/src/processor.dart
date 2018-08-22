import 'dart:async' show Future;

import 'package:barback/barback.dart' show AssetId, Transform;
import 'package:html/dom.dart' show Document, Element;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

Map<AssetId, int> _counter = <AssetId, int>{};
Map<String, AssetId> _linksMap = <String, AssetId>{};

/// <T> - type of returned document
abstract class Processor<T, E> {
  static final String prefix = 'static';

  AssetId id;
  Transform transform;
  T document;
  final Map<String, String> headers;

  Processor(this.id, this.transform, this.document, String userAgent)
    : headers = { 'User-Agent': userAgent ?? 'mk_static' };

  String get userAgent => headers['User-Agent'];

  String checkMapping(String href) {
    AssetId id = _linksMap[href];
    if (id == null) {
      return null;
    }
    String mapped = getHref(id);
    debug('Already mapped $mapped=$href');
    return mapped;
  }

  void addMapping(String href, AssetId id) {
    _linksMap[href] = id;
    info(transform, 'Add mapping ${getHref(id)}=$href');
  }

  AssetId createMapping(String href, String newExtension) {
    AssetId id = newId(newExtension);
    addMapping(href, id);
    return id;
  }

  String getHref(AssetId id) {
    return path.basename(id.path);
  }

  AssetId newId(String newExtension) {
    if (!_counter.containsKey(id)) {
      _counter[id] = 0;
    }

    //return id.changeExtension('_${prefix}_${_counter[id]++}$newExtension');
    return new AssetId(id.package, path.dirname(id.path)
        + path.separator
        + prefix
        + '_${_counter[id]++}'
        + newExtension);
  }

  void debug(String message) {
    transform.logger.fine(message);
  }

  void info(Transform transform, String message) {
    transform.logger.info(message);
  }

  Iterable<E> query();

  bool accept(E e);

  Future<Null> processOne(E e);

  Future<T> run() async {
    await Future.forEach(query().where(accept), processOne);
    return document;
  }
}

abstract class DocumentProcessor extends Processor<Document, Element> {
  DocumentProcessor(AssetId id, Transform transform, Document document,
    String userAgent) : super(id, transform, document, userAgent);

  bool isExternalUrl(String url) =>
    url != null && (url.startsWith('http') || url.startsWith('//'));

  Future<String> readExternalUrl(String url) async {
    if (url.startsWith('//')) {
      try {
        return await http.read("https:$url", headers: headers);
      } catch (err) {
        return await http.read("http:$url", headers: headers);
      }
    }
    return await http.read(url, headers: headers);
  }

  String ensureProcess(Element e);

  AssetId createElementMapping(String href);

  Future<String> processExternal(Element e, AssetId assetId, String href);

  void produceOutput(Element e, AssetId assetId, String data);

  @override
  Future<Null> processOne(Element e) async {
    String href = ensureProcess(e);
    if (href == null) {
      return;
    }

    AssetId elementAssetId = createElementMapping(href);
    debug('Downloading external: $href');
    String newData = await processExternal(e, elementAssetId, href);
    produceOutput(e, elementAssetId, newData);
  }
}

