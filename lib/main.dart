import 'package:finite_field_calculator/parsing.dart';
import 'package:finite_field_calculator/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'polynomial.dart';

void main() => runApp(const FiniteFieldApp());

class FiniteFieldApp extends StatelessWidget {
  const FiniteFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Finite Field Calculator",
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final TextEditingController _textController = .new();
  late final FocusNode _focusNode;
  String _result = "";

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onStateChanged);

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          String? char = event.character;

          if (key == LogicalKeyboardKey.backspace) {
            _onPressed("⌫");
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            _onPressed("=");
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            _onPressed("←");
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            _onPressed("→");
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.delete) {
            _onPressed("C");
            return KeyEventResult.handled;
          } else if (char != null) {
            if ("0123456789+-^()".contains(char)) {
              _onPressed(char);
              return KeyEventResult.handled;
            } else if (char == '*' || char.toLowerCase() == 'x') {
              _onPressed(char == '*' ? '×' : 'x');
              return KeyEventResult.handled;
            } else if (char.toLowerCase() == 'i') {
              _onPressed('⁻¹');
              return KeyEventResult.handled;
            } else if (char == '=') {
              _onPressed('=');
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    fieldOrder.addListener(_onStateChanged);
    isPolynomialMode.addListener(_onStateChanged);
    reducingPolyString.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    fieldOrder.removeListener(_onStateChanged);
    isPolynomialMode.removeListener(_onStateChanged);
    reducingPolyString.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _calculate();
      });
    } else {
      setState(() {
        _result = "";
      });
    }
  }

  void _onPressed(String value) {
    final text = _textController.text;
    final selection = _textController.selection;

    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    String newText = text;
    int newOffset = start;

    if (value == "C") {
      newText = "";
      newOffset = 0;
    } else if (value == "⌫") {
      if (start != end) {
        newText = text.replaceRange(start, end, "");
        newOffset = start;
      } else if (start > 0) {
        int len = (start >= 2 && text.substring(start - 2, start) == "⁻¹")
            ? 2
            : 1;
        newText = text.replaceRange(start - len, start, "");
        newOffset = start - len;
      } else {
        return;
      }
    } else if (value == "=") {
      _calculate();
      return;
    } else if (value == "←") {
      if (start > 0) {
        int step = (start >= 2 && text.substring(start - 2, start) == "⁻¹")
            ? 2
            : 1;
        newOffset = start - step;
      }
    } else if (value == "→") {
      if (start < text.length) {
        int step =
            (start + 2 <= text.length &&
                text.substring(start, start + 2) == "⁻¹")
            ? 2
            : 1;
        newOffset = start + step;
      }
    } else {
      bool isBinaryOp(String s) => ["+", "-", "×", "^"].contains(s);

      // Check if we are starting a negative exponent
      bool isNegativeExponentTrigger =
          (start > 0 && text[start - 1] == "^" && value == "-") ||
          (start > 1 &&
              text.substring(start - 2, start) == "^(" &&
              value == "-");

      // Only swap operators if we aren't currently trying to type a negative power
      if (start == end &&
          !isNegativeExponentTrigger &&
          isBinaryOp(value) &&
          start > 0 &&
          isBinaryOp(text[start - 1])) {
        newText = text.replaceRange(start - 1, start, value);
        newOffset = start;
      } else {
        newText = text.replaceRange(start, end, value);
        newOffset = start + value.length;

        if (newOffset >= 2 &&
            newText.substring(newOffset - 2, newOffset) == "^-") {
          newText = newText.replaceRange(newOffset - 2, newOffset, "⁻¹^");
          newOffset = newText.indexOf("^", start) + 1;
        } else if (newOffset >= 3 &&
            newText.substring(newOffset - 3, newOffset) == "^(-") {
          newText = newText.replaceRange(newOffset - 3, newOffset, "⁻¹^(");
          newOffset = newText.indexOf("(", start) + 1;
        }
      }
    }

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _focusNode.requestFocus();
  }

  void _calculate() {
    if (_textController.text.isEmpty) {
      _result = "";
      return;
    }
    try {
      final res = evaluateExpression(
        _textController.text,
        fieldOrder.value,
        isPolynomialMode.value,
        reducingPolyString.value,
      );
      _result = "= $res";
    } catch (e) {
      _result = "Error";
    }
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, -1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: isPolynomialMode,
          builder: (context, isPoly, _) {
            return ValueListenableBuilder<int>(
              valueListenable: fieldOrder,
              builder: (context, pValue, _) {
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "ℤ$pValue",
                        style: const TextStyle(
                          fontFeatures: [FontFeature.subscripts()],
                        ),
                      ),
                      if (isPoly) ...[
                        TextSpan(text: " [x] / ("),
                        TextSpan(
                          text: reducingPolyString.value.replaceAllMapped(
                            RegExp(r'\^(\d+)'),
                            (Match m) => m
                                .group(1)!
                                .split('')
                                .map(_digitToSuperScript)
                                .join(''),
                          ),
                        ),
                        TextSpan(text: ")"),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, _createRoute());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 100) {
                    Navigator.push(context, _createRoute());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        readOnly: true,
                        keyboardType: TextInputType.none,
                        showCursor: true,
                        autofocus: true,
                        textAlign: TextAlign.right,
                        onTapOutside: (PointerDownEvent event) {},
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        selectAllOnFocus: false,
                      ),
                      if (_result.isNotEmpty)
                        SelectableText(
                          _result,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  String _digitToSuperScript(String c) =>
      {
        '0': '⁰',
        '1': '¹',
        '2': '²',
        '3': '³',
        '4': '⁴',
        '5': '⁵',
        '6': '⁶',
        '7': '⁷',
        '8': '⁸',
        '9': '⁹',
      }[c] ??
      c;

  Widget _buildKeypad() {
    Widget buildRow(List<Widget> children) {
      return Row(
        children: children
            .map(
              (w) => Expanded(
                child: Padding(padding: const EdgeInsets.all(4.0), child: w),
              ),
            )
            .toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black26,
      child: Column(
        children: [
          buildRow([
            _buildButton('←'),
            _buildButton('→'),
            _buildButton('='),
            _buildButton('⌫', secondary: 'C'),
          ]),
          buildRow([
            _buildButton('7'),
            _buildButton('8'),
            _buildButton('9'),
            _buildButton('+'),
          ]),
          buildRow([
            _buildButton('4'),
            _buildButton('5'),
            _buildButton('6'),
            _buildButton('-'),
          ]),
          buildRow([
            _buildButton('1'),
            _buildButton('2'),
            _buildButton('3'),
            _buildButton('×', secondary: '⁻¹'),
          ]),
          buildRow([
            _buildButton('('),
            _buildButton('0', secondary: 'x'),
            _buildButton(')'),
            _buildButton('^'),
          ]),
        ],
      ),
    );
  }

  Widget _buildButton(String primary, {String? secondary}) {
    bool isAction = ["C", "⌫", "="].contains(primary);
    bool isOp = ["+", "×", "-", "(", ")", "^", "⁻¹"].contains(primary);
    bool isArrow = ["←", "→"].contains(primary);

    Color? getButtonColor() {
      if (isAction) return Colors.orange;
      if (isArrow) return Colors.blueGrey[600];
      if (isOp) return Colors.blueGrey[700];
      return Colors.blueGrey[900];
    }

    return ExcludeFocus(
      child: ElevatedButton(
        focusNode: FocusNode(canRequestFocus: false),
        style: ElevatedButton.styleFrom(
          backgroundColor: getButtonColor(),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          _onPressed(primary);
        },
        onLongPress: secondary != null
            ? () {
                HapticFeedback.heavyImpact();
                _onPressed(secondary);
              }
            : null,
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  primary,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (secondary != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Text(
                    secondary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorCursor extends StatelessWidget {
  const CalculatorCursor({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, height: 32, color: Colors.white);
  }
}

String evaluateExpression(
  String expression,
  int p,
  bool isPoly,
  String modStr,
) {
  if (expression.isEmpty) return "0";

  Polynomial? modulus;
  if (isPoly && modStr.trim().isNotEmpty) {
    modulus = parsePolynomial(modStr, p, true, null);
  }

  Polynomial result = parsePolynomial(expression, p, isPoly, modulus);
  return result.toString();
}
