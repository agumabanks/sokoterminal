import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/amara/terminal_identity_publisher.dart';
void main() {
  test('logout invalidates an in-flight proof before it can reach Amara', () async {
    final response=Completer<String>();final writes=<String>[];
    final publisher=TerminalIdentityPublisher(fetch:()=>response.future,publish:(proof,generation)async{writes.add(proof);});
    final login=publisher.setAuthenticated(true);
    await Future<void>.delayed(Duration.zero);
    await publisher.setAuthenticated(false);
    response.complete('old-shop');await login;
    expect(writes,everyElement(isEmpty));publisher.dispose();
  });
  test('failed authentication clears the previous identity', () async {
    final writes=<String>[];bool fail=false;
    final publisher=TerminalIdentityPublisher(fetch:()async{if(fail)throw Exception('expired');return 'shop-a';},publish:(proof,generation)async{writes.add(proof);});
    await publisher.setAuthenticated(true);expect(writes.last,'shop-a');
    fail=true;await publisher.setAuthenticated(true);expect(writes.last,isEmpty);publisher.dispose();
  });
  test('on-demand refresh fetches a new proof without waiting for the timer', () async {
    int fetched=0; final writes=<String>[];
    final publisher=TerminalIdentityPublisher(fetch:() async=>'shop-${++fetched}', publish:(proof,generation) async{writes.add(proof);});
    expect(await publisher.refreshNow(),isFalse);
    await publisher.setAuthenticated(true);
    expect(writes.last,'shop-1');
    expect(await publisher.refreshNow(),isTrue);
    expect(writes.last,'shop-2');
    await publisher.setAuthenticated(false);
    expect(await publisher.refreshNow(),isFalse);
    expect(writes.last,isEmpty);publisher.dispose();
  });
  test('logout also rejects a late on-demand refresh', () async {
    final late=Completer<String>();int fetches=0;final writes=<String>[];
    final publisher=TerminalIdentityPublisher(fetch:() async {if(++fetches==1)return 'first';return late.future;},publish:(p,g)async{writes.add(p);});
    await publisher.setAuthenticated(true);
    final refresh=publisher.refreshNow();
    await publisher.setAuthenticated(false);
    late.complete('old-shop');
    expect(await refresh,isFalse);expect(writes.last,isEmpty);publisher.dispose();
  });
}
