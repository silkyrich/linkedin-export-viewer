import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web drop zone: listens for drag-and-drop events at the document level
/// so a user can drop a zip anywhere on the page. Shows a translucent
/// "Drop your LinkedIn zip" overlay while a drag is hovering.
class DropZone extends StatefulWidget {
  const DropZone({
    required this.child,
    required this.onDrop,
    super.key,
  });

  final Widget child;
  final void Function(Uint8List bytes, String name) onDrop;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;
  late final JSFunction _dragOverListener;
  late final JSFunction _dragLeaveListener;
  late final JSFunction _dropListener;

  @override
  void initState() {
    super.initState();

    _dragOverListener = ((web.Event e) {
      e.preventDefault();
      if (!_hovering) setState(() => _hovering = true);
    }).toJS;

    _dragLeaveListener = ((web.Event e) {
      // "dragleave" fires when moving between nested elements too. Guard by
      // checking that the pointer actually left the viewport.
      final de = e as web.DragEvent;
      if (de.clientX == 0 && de.clientY == 0) {
        if (_hovering) setState(() => _hovering = false);
      }
    }).toJS;

    _dropListener = ((web.Event e) {
      e.preventDefault();
      if (_hovering) setState(() => _hovering = false);
      final dropEvent = e as web.DragEvent;
      final files = dropEvent.dataTransfer?.files;
      if (files == null || files.length == 0) return;
      final file = files.item(0);
      if (file == null) return;
      _readBytes(file).then((bytes) {
        if (bytes != null) widget.onDrop(bytes, file.name);
      });
    }).toJS;

    web.document.addEventListener('dragover', _dragOverListener);
    web.document.addEventListener('dragleave', _dragLeaveListener);
    web.document.addEventListener('drop', _dropListener);
  }

  @override
  void dispose() {
    web.document.removeEventListener('dragover', _dragOverListener);
    web.document.removeEventListener('dragleave', _dragLeaveListener);
    web.document.removeEventListener('drop', _dropListener);
    super.dispose();
  }

  Future<Uint8List?> _readBytes(web.File file) {
    final completer = Completer<Uint8List?>();
    final reader = web.FileReader();
    late final JSFunction onLoad;
    late final JSFunction onError;
    onLoad = ((web.Event _) {
      final result = reader.result;
      if (result.isA<JSArrayBuffer>()) {
        completer.complete((result as JSArrayBuffer).toDart.asUint8List());
      } else {
        completer.complete(null);
      }
      reader.removeEventListener('load', onLoad);
      reader.removeEventListener('error', onError);
    }).toJS;
    onError = ((web.Event _) {
      completer.complete(null);
      reader.removeEventListener('load', onLoad);
      reader.removeEventListener('error', onError);
    }).toJS;
    reader.addEventListener('load', onLoad);
    reader.addEventListener('error', onError);
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        widget.child,
        if (_hovering)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Drop your LinkedIn zip',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
