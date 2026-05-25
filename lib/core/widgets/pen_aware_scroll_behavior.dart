import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

class PenAwareScrollBehavior extends MaterialScrollBehavior {
  const PenAwareScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        ...super.dragDevices,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
