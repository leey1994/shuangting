import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final url = args[0];
  final ws = await WebSocket.connect(url);
  var id = 0;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final rid = msg['id'];
    if (rid is int && pending.containsKey(rid)) {
      pending.remove(rid)!.complete(msg);
    }
  });
  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> params) {
    final cid = ++id;
    final c = Completer<Map<String, dynamic>>();
    pending[cid] = c;
    ws.add(jsonEncode({'jsonrpc': '2.0', 'id': cid, 'method': method, 'params': params}));
    return c.future.timeout(const Duration(seconds: 20));
  }

  final vm = await call('getVM', {});
  final isolates = (vm['result']?['isolates'] as List?) ?? [];
  print('isolates: ${isolates.map((e) => e['name']).toList()}');
  final iso = isolates.first['id'] as String;
  for (final method in ['ext.flutter.debugDumpRenderTree', 'ext.flutter.debugDumpApp']) {
    try {
      final r = await call(method, {'isolateId': iso});
      final txt = jsonEncode(r['result']);
      print('--- $method (${txt.length} bytes)');
      print(txt.substring(0, txt.length > 3000 ? 3000 : txt.length));
    } catch (e) {
      print('--- $method failed: $e');
    }
  }
  for (final method in ['_flutter.screenshot', '_flutter.screenshotSkp']) {
    try {
      final r = await call(method, {'isolateId': iso});
      final result = r['result'];
      if (result is Map && result['screenshot'] is String) {
        final bytes = base64Decode(result['screenshot'] as String);
        File(args.length > 1 ? args[1] : 'shot_from_vm.png').writeAsBytesSync(bytes);
        print('--- $method saved ${bytes.length} bytes');
      } else {
        print('--- $method -> ${jsonEncode(result).substring(0, 200)}');
      }
    } catch (e) {
      print('--- $method failed: $e');
    }
  }
  await ws.close();
}
