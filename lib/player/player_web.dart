// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildPlayer(BuildContext context, String embedUrl) {
  // Use URL hash to create a unique view type so each channel gets its own unique iframe
  final String viewType = 'iframe-stream-${embedUrl.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('sandbox', 'allow-scripts allow-forms allow-same-origin allow-presentation');
      return iframe;
    },
  );

  return HtmlElementView(viewType: viewType);
}
