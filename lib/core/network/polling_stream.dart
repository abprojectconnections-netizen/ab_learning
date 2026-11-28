import 'dart:async';

/// A stream that loads immediately on listen, then again every [interval] and
/// whenever [refresh] emits. Used for REST data that Firestore used to push
/// live. Overlapping triggers are coalesced into one follow-up load.
Stream<T> pollingStream<T>(
  Future<T> Function() load, {
  Duration interval = const Duration(seconds: 60),
  Stream<void>? refresh,
}) {
  late final StreamController<T> controller;
  Timer? timer;
  StreamSubscription<void>? refreshSub;
  var busy = false;
  var pending = false;

  Future<void> tick() async {
    if (controller.isClosed) return;
    if (busy) {
      pending = true;
      return;
    }
    busy = true;
    try {
      final value = await load();
      if (!controller.isClosed) controller.add(value);
    } catch (error, stack) {
      if (!controller.isClosed) controller.addError(error, stack);
    } finally {
      busy = false;
    }
    if (pending) {
      pending = false;
      await tick();
    }
  }

  controller = StreamController<T>(
    onListen: () {
      tick();
      timer = Timer.periodic(interval, (_) => tick());
      refreshSub = refresh?.listen((_) => tick());
    },
    onCancel: () async {
      timer?.cancel();
      await refreshSub?.cancel();
    },
  );
  return controller.stream;
}
