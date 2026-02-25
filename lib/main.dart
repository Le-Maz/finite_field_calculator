import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const FiniteFieldApp());

final ValueNotifier<int> fieldOrder = ValueNotifier<int>(257);

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
  String _expression = "";
  String _result = "";
  int _cursorPosition = 0;

  @override
  void initState() {
    super.initState();
    fieldOrder.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    fieldOrder.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    if (_expression.isNotEmpty &&
        _result.isNotEmpty &&
        !_result.contains("Error")) {
      setState(() {
        _calculate();
      });
    }
  }

  void _onPressed(String value) {
    setState(() {
      if (value == "C") {
        _expression = "";
        _result = "";
        _cursorPosition = 0;
      } else if (value == "⌫") {
        if (_cursorPosition > 0) {
          int len = 1;
          if (_cursorPosition >= 2 &&
              _expression.substring(_cursorPosition - 2, _cursorPosition) ==
                  "⁻¹") {
            len = 2;
          }
          _expression =
              _expression.substring(0, _cursorPosition - len) +
              _expression.substring(_cursorPosition);
          _cursorPosition -= len;
        }
      } else if (value == "=") {
        _calculate();
      } else if (value == "←") {
        if (_cursorPosition > 0) {
          if (_cursorPosition >= 2 &&
              _expression.substring(_cursorPosition - 2, _cursorPosition) ==
                  "⁻¹") {
            _cursorPosition -= 2;
          } else {
            _cursorPosition--;
          }
        }
      } else if (value == "→") {
        if (_cursorPosition < _expression.length) {
          if (_cursorPosition + 2 <= _expression.length &&
              _expression.substring(_cursorPosition, _cursorPosition + 2) ==
                  "⁻¹") {
            _cursorPosition += 2;
          } else {
            _cursorPosition++;
          }
        }
      } else {
        bool isBinaryOp(String s) => ["+", "-", "×", "^"].contains(s);
        bool isLastCharBinaryOp =
            _cursorPosition > 0 && isBinaryOp(_expression[_cursorPosition - 1]);

        if (isBinaryOp(value) && isLastCharBinaryOp) {
          _expression =
              _expression.substring(0, _cursorPosition - 1) +
              value +
              _expression.substring(_cursorPosition);
        } else {
          _expression =
              _expression.substring(0, _cursorPosition) +
              value +
              _expression.substring(_cursorPosition);
          _cursorPosition += value.length;
        }
      }
    });
  }

  void _calculate() {
    try {
      final currentField = fieldOrder.value;
      final res = evaluateExpression(_expression, currentField);
      _result = "= $res";
    } catch (e) {
      _result = "Error: Invalid Input";
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
    String leftPart = _expression.substring(0, _cursorPosition);
    String rightPart = _expression.substring(_cursorPosition);

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: fieldOrder,
          builder: (context, value, child) {
            return Text("GF($value) Calculator");
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
                      SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: leftPart),
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              baseline: TextBaseline.alphabetic,
                              child: CalculatorCursor(),
                            ),
                            TextSpan(text: rightPart),
                          ],
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
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
            _buildButton('0'),
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

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: getButtonColor(),
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  bool _isCurrentPrime = true;

  final List<Map<String, dynamic>> _funPrimes = [
    {"value": 11, "label": "Sophie Germain"},
    {"value": 37, "label": "Star Prime"},
    {"value": 101, "label": "Palindromic"},
    {"value": 127, "label": "Mersenne (M₇)"},
    {"value": 257, "label": "Fermat (F₄)"},
    {"value": 65537, "label": "Fermat (F₅)"},
    {"value": 1000000007, "label": "Competitive"},
    {"value": 2147483647, "label": "Mersenne (M₃₁)"},
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: fieldOrder.value.toString());
    _isCurrentPrime = _isPrime(fieldOrder.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOrder(int newOrder) {
    setState(() {
      _isCurrentPrime = _isPrime(newOrder);
    });
    if (newOrder > 1) {
      fieldOrder.value = newOrder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -100) {
            Navigator.pop(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Finite Field Order (p)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter a prime number to define the field size.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Field Order",
                  prefixIcon: Icon(Icons.tag),
                ),
                onChanged: (value) {
                  final int? newOrder = int.tryParse(value);
                  if (newOrder != null) {
                    _updateOrder(newOrder);
                  } else {
                    setState(() => _isCurrentPrime = false);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _isCurrentPrime ? Icons.check_circle : Icons.error,
                    color: _isCurrentPrime ? Colors.green : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCurrentPrime
                          ? "This is a prime number."
                          : "Not a prime! Field arithmetic may throw errors.",
                      style: TextStyle(
                        color: _isCurrentPrime
                            ? Colors.green
                            : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                "Fun Primes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: _funPrimes.map((primeData) {
                  final int pValue = primeData["value"];
                  final String pLabel = primeData["label"];
                  return ActionChip(
                    avatar: const Icon(Icons.star, size: 16),
                    label: Text("$pValue"),
                    tooltip: pLabel,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      _controller.text = pValue.toString();
                      _updateOrder(pValue);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isPrime(int n) {
  if (n <= 1) return false;
  if (n <= 3) return true;
  if (n % 2 == 0) return false;

  int d = n - 1;
  int s = 0;
  while (d % 2 == 0) {
    d ~/= 2;
    s++;
  }

  const List<int> bases = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];

  for (int a in bases) {
    if (n <= a) break;

    int x = BigInt.from(a).modPow(BigInt.from(d), BigInt.from(n)).toInt();

    if (x == 1 || x == n - 1) continue;

    bool composite = true;
    for (int r = 1; r < s; r++) {
      x = BigInt.from(x).modPow(BigInt.from(2), BigInt.from(n)).toInt();
      if (x == n - 1) {
        composite = false;
        break;
      }
    }
    if (composite) return false;
  }
  return true;
}

int evaluateExpression(String expression, int p) {
  if (expression.isEmpty) return 0;
  final tokens = _tokenize(expression);
  final rpn = _toRPN(tokens);
  return _evaluateRPN(rpn, p);
}

List<String> _tokenize(String expression) {
  final regex = RegExp(r'(\d+|[+\-×()^]|⁻¹)');
  return regex.allMatches(expression).map((e) => e.group(0)!).toList();
}

int _getPrecedence(String op) {
  if (op == '+' || op == '-') return 1;
  if (op == '×') return 2;
  if (op == '^' || op == '⁻¹') return 3;
  return 0;
}

List<String> _toRPN(List<String> tokens) {
  List<String> output = [];
  List<String> stack = [];

  for (var token in tokens) {
    if (int.tryParse(token) != null) {
      output.add(token);
    } else if (token == '(') {
      stack.add(token);
    } else if (token == ')') {
      while (stack.isNotEmpty && stack.last != '(') {
        output.add(stack.removeLast());
      }
      if (stack.isNotEmpty) stack.removeLast();
    } else {
      while (stack.isNotEmpty &&
          _getPrecedence(stack.last) >= _getPrecedence(token)) {
        output.add(stack.removeLast());
      }
      stack.add(token);
    }
  }
  while (stack.isNotEmpty) {
    output.add(stack.removeLast());
  }
  return output;
}

int _evaluateRPN(List<String> tokens, int p) {
  List<int> stack = [];
  for (var token in tokens) {
    if (int.tryParse(token) != null) {
      stack.add(int.parse(token) % p);
    } else if (token == '⁻¹') {
      if (stack.isEmpty) throw Exception();
      int a = stack.removeLast();
      if (a == 0) throw Exception();
      stack.add(extendedGCD(a, p));
    } else {
      if (stack.length < 2) throw Exception();
      int b = stack.removeLast();
      int a = stack.removeLast();
      switch (token) {
        case '+':
          stack.add((a + b) % p);
          break;
        case '-':
          stack.add((a - b + p) % p);
          break;
        case '×':
          stack.add((a * b) % p);
          break;
        case '^':
          stack.add(_modPow(a, b, p));
          break;
      }
    }
  }
  return stack.isEmpty ? 0 : stack.first;
}

int _modPow(int base, int exponent, int modulus) {
  if (modulus == 1) return 0;
  int result = 1;
  base = base % modulus;

  if (exponent < 0) {
    base = extendedGCD(base, modulus);
    exponent = -exponent;
  }

  while (exponent > 0) {
    if (exponent % 2 == 1) {
      result = (result * base) % modulus;
    }
    exponent = exponent >> 1;
    base = (base * base) % modulus;
  }
  return result;
}

int extendedGCD(int a, int m) {
  int m0 = m, t, q;
  int x0 = 0, x1 = 1;

  if (m == 1) return 0;

  while (a > 1) {
    if (m == 0) throw Exception();
    q = a ~/ m;
    t = m;
    m = a % m;
    a = t;
    t = x0;
    x0 = x1 - q * x0;
    x1 = t;
  }
  if (x1 < 0) x1 += m0;
  return x1;
}
