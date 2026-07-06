import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

Widget buildPlayer(BuildContext context, String embedUrl) {
  if (Platform.isAndroid || Platform.isIOS) {
    return NativeWebView(embedUrl: embedUrl);
  } else if (Platform.isWindows) {
    return WindowsWebView(embedUrl: embedUrl);
  } else {
    return const Center(
      child: Text(
        'Platform not supported',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

// Android & iOS WebView implementation
class NativeWebView extends StatefulWidget {
  final String embedUrl;
  const NativeWebView({super.key, required this.embedUrl});

  @override
  State<NativeWebView> createState() => _NativeWebViewState();
}

class _NativeWebViewState extends State<NativeWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            // Intercept and prevent external redirects/popups
            final host = Uri.parse(request.url).host.toLowerCase();
            final embedHost = Uri.parse(widget.embedUrl).host.toLowerCase();
            
            // Allow same origin and streaming engine hosts, block everything else
            if (host == embedHost || 
                host.contains('daddylive') || 
                host.contains('daddy') || 
                host.contains('wms') || 
                host.contains('stream')) {
              return NavigationDecision.navigate;
            }
            debugPrint('Prevented Android webview redirect to: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  void didUpdateWidget(NativeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedUrl != widget.embedUrl) {
      _controller.loadRequest(Uri.parse(widget.embedUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
      ],
    );
  }
}

// Windows WebView implementation
class WindowsWebView extends StatefulWidget {
  final String embedUrl;
  const WindowsWebView({super.key, required this.embedUrl});

  @override
  State<WindowsWebView> createState() => _WindowsWebViewState();
}

class _WindowsWebViewState extends State<WindowsWebView> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();
      // WebviewPopupWindowPolicy.deny denies window.open popups to prevent redirects
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl(widget.embedUrl);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void didUpdateWidget(WindowsWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedUrl != widget.embedUrl) {
      if (_isInitialized) {
        _controller.loadUrl(widget.embedUrl);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Failed to load Windows WebView:\n$_error\n\nMake sure the Edge WebView2 Runtime is installed.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return Webview(_controller);
  }
}
