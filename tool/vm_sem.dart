import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final rid = msg['id'];
    if (rid is int && pending.containsKey(rid)) pending.remove(rid)!.complete(msg);
  });
  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> params) {
    final cid = ++id;
    final c = Completer<Map<String, dynamic>>();
    pending[cid] = c;
    ws.add(jsonEncode({'jsonrpc': '2.0', 'id': cid, 'method': method, 'params': params}));
    return c.future.timeout(const Duration(seconds: 20));
  }

  final vm = await call('getVM', {});
  final iso = ((vm['result']?['isolates'] as List?)?.first)['id'] as String;
  final r = await call('ext.flutter.debugDumpSemanticsTreeInTraversalOrder', {'isolateId': iso});
  final txt = (r['result'] as Map?)?['data']?.toString() ?? jsonEncode(r);
  File(args[1]).writeAsStringSync(txt);
  print('saved ${txt.length} chars');
  await ws.close();
}
