library flutter_echarts;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'echarts_script.dart' show echartsScript;

/// <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=0, target-densitydpi=device-dpi" /><style type="text/css">body,html,#chart{height: 100%;width: 100%;margin: 0px;}div {-webkit-tap-highlight-color:rgba(255,255,255,0);}</style></head><body><div id="chart" /></body></html>
/// 'data:text/html;base64,' + base64Encode(const Utf8Encoder().convert( /* STRING ABOVE */ ))
const htmlBase64 =
    'PCFET0NUWVBFIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Utd2lkdGgsIGluaXRpYWwtc2NhbGU9MS4wLCBtYXhpbXVtLXNjYWxlPTEuMCwgbWluaW11bS1zY2FsZT0xLjAsIHVzZXItc2NhbGFibGU9MCwgdGFyZ2V0LWRlbnNpdHlkcGk9ZGV2aWNlLWRwaSIgLz48c3R5bGUgdHlwZT0idGV4dC9jc3MiPmJvZHksaHRtbCwjY2hhcnR7aGVpZ2h0OiAxMDAlO3dpZHRoOiAxMDAlO21hcmdpbjogMHB4O31kaXYgey13ZWJraXQtdGFwLWhpZ2hsaWdodC1jb2xvcjpyZ2JhKDI1NSwyNTUsMjU1LDApO308L3N0eWxlPjwvaGVhZD48Ym9keT48ZGl2IGlkPSJjaGFydCIgLz48L2JvZHk+PC9odG1sPg==';

class Echarts extends StatefulWidget {
  Echarts(
      {Key? key,
      required this.option,
      this.extraScript = '',
      this.onMessage,
      this.extensions = const [],
      this.theme,
      this.captureAllGestures = false,
      this.captureHorizontalGestures = false,
      this.captureVerticalGestures = false,
      this.onLoad,
      this.onWebResourceError,
      this.reloadAfterInit = false})
      : super(key: key);

  final String option;

  final String extraScript;

  final void Function(String message)? onMessage;

  final List<String> extensions;

  final String? theme;

  final bool captureAllGestures;

  final bool captureHorizontalGestures;

  final bool captureVerticalGestures;

  final void Function(WebViewController)? onLoad;

  final void Function(WebViewController, Exception)? onWebResourceError;

  final bool reloadAfterInit;

  @override
  _EchartsState createState() => _EchartsState();
}

class _EchartsState extends State<Echarts> {
  WebViewController? _controller;

  String? _currentOption;

  @override
  void initState() {
    super.initState();
    _currentOption = widget.option;

    _controller = WebViewController()
      ..setBackgroundColor(Color(0x00000000))
      ..loadHtmlString(utf8.fuse(base64).decode(htmlBase64))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) => init(),
          onWebResourceError: (e) {
            if (widget.onWebResourceError != null) {
              widget.onWebResourceError!(_controller!, Exception(e));
            }
          },
        ),
      )
      ..addJavaScriptChannel('Messager', onMessageReceived: (JavaScriptMessage javascriptMessage) {
        if (widget.onMessage != null) {
          widget.onMessage!(javascriptMessage.message);
        }
      });

    if (widget.reloadAfterInit) {
      new Future.delayed(const Duration(milliseconds: 100), () {
        _controller?.reload();
      });
    }
  }

  void init() async {
    final extensionsStr = this.widget.extensions.length > 0
        ? this.widget.extensions.reduce((value, element) => value + '\n' + element)
        : '';
    final themeStr = this.widget.theme != null ? '\'${this.widget.theme}\'' : 'null';

    // First initialize the chart
    await _controller?.runJavaScript('''
      $echartsScript
      $extensionsStr
      var chart = echarts.init(document.getElementById('chart'), $themeStr);
      chart.setOption($_currentOption, true);
    ''');

    // Then add the event handlers in a separate call
    await _controller?.runJavaScript('''
      // Make sure we don't have circular references
      ${this.widget.extraScript}
    ''');

    if (widget.onLoad != null) {
      widget.onLoad!(_controller!);
    }
  }

  Set<Factory<OneSequenceGestureRecognizer>> getGestureRecognizers() {
    Set<Factory<OneSequenceGestureRecognizer>> set = Set();
    if (this.widget.captureAllGestures || this.widget.captureHorizontalGestures) {
      set.add(Factory<HorizontalDragGestureRecognizer>(() {
        return HorizontalDragGestureRecognizer()
          ..onStart = (DragStartDetails details) {}
          ..onUpdate = (DragUpdateDetails details) {}
          ..onDown = (DragDownDetails details) {}
          ..onCancel = () {}
          ..onEnd = (DragEndDetails details) {};
      }));
    }
    if (this.widget.captureAllGestures || this.widget.captureVerticalGestures) {
      set.add(Factory<VerticalDragGestureRecognizer>(() {
        return VerticalDragGestureRecognizer()
          ..onStart = (DragStartDetails details) {}
          ..onUpdate = (DragUpdateDetails details) {}
          ..onDown = (DragDownDetails details) {}
          ..onCancel = () {}
          ..onEnd = (DragEndDetails details) {};
      }));
    }
    return set;
  }

  void update(String preOption) async {
    _currentOption = widget.option;
    if (_currentOption != preOption) {
      await _controller?.runJavaScript('''
        try {
          chart.setOption($_currentOption, true);
        } catch(e) {
        }
      ''');
    }
  }

  @override
  void didUpdateWidget(Echarts oldWidget) {
    super.didUpdateWidget(oldWidget);
    update(oldWidget.option);
  }

  @override
  void dispose() {
    _controller?.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller!, gestureRecognizers: getGestureRecognizers());
  }
}
