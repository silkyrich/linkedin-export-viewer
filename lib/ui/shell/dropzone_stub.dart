import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Non-web stub. Drag-and-drop is a browser feature; outside the browser
/// we just render the child unchanged.
class DropZone extends StatelessWidget {
  const DropZone({
    required this.child,
    required this.onDrop,
    super.key,
  });

  final Widget child;
  final void Function(Uint8List bytes, String name) onDrop;

  @override
  Widget build(BuildContext context) => child;
}
