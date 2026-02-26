import 'package:finite_field_calculator/parsing.dart';
import 'package:finite_field_calculator/polynomial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final ValueNotifier<int> fieldOrder = .new(127);
final ValueNotifier<bool> isPolynomialMode = .new(false);
final ValueNotifier<String> reducingPolyString = .new("x^2 + 1");

class FunPrime {
  final int value;
  final String label;
  final IconData icon;

  const FunPrime({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class StandardPoly {
  final String poly;
  final String label;

  const StandardPoly({required this.poly, required this.label});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _pController;
  late final TextEditingController _modController;
  bool _isCurrentPrime = true;
  bool _isModPolyValid = true;
  bool _isModPolyIrreducible = true;

  final List<FunPrime> _funPrimes = const [
    FunPrime(value: 2, label: "Binary", icon: Icons.looks_two),
    FunPrime(value: 11, label: "Sophie Germain", icon: Icons.diamond),
    FunPrime(value: 101, label: "Palindromic", icon: Icons.swap_horiz),
    FunPrime(value: 127, label: "Mersenne (M₇)", icon: Icons.memory),
    FunPrime(value: 257, label: "Fermat (F₄)", icon: Icons.architecture),
    FunPrime(value: 65537, label: "Fermat (F₅)", icon: Icons.account_balance),
    FunPrime(value: 1000000007, label: "Competitive", icon: Icons.emoji_events),
    FunPrime(value: 2147483647, label: "Mersenne (M₃₁)", icon: Icons.speed),
  ];

  final List<StandardPoly> _standardPolys = const [
    StandardPoly(poly: "", label: "No Modulus"),
    StandardPoly(poly: "x^2 + 1", label: "Complex-like"),
    StandardPoly(poly: "x^2 + x + 1", label: "Degree 2 minimum"),
    StandardPoly(poly: "x^3 + x + 1", label: "Degree 3 minimum"),
    StandardPoly(poly: "x^4 + x + 1", label: "Nibble operations"),
    StandardPoly(poly: "x^8 + x^4 + x^3 + x + 1", label: "AES standard"),
    StandardPoly(poly: "x^8 + x^6 + x^5 + x^3 + 1", label: "Camellia standard"),
  ];

  List<StandardPoly> _filteredPolys = [];

  @override
  void initState() {
    super.initState();
    _pController = TextEditingController(text: fieldOrder.value.toString());
    _modController = TextEditingController(text: reducingPolyString.value);
    _isCurrentPrime = _isPrime(fieldOrder.value);
    _validateModPoly();
    _updateFilteredPolys();
  }

  @override
  void dispose() {
    _pController.dispose();
    _modController.dispose();
    super.dispose();
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

  String _formatPoly(String poly) {
    if (poly.isEmpty) return "Empty";
    return poly.replaceAllMapped(
      RegExp(r'\^(\d+)'),
      (Match m) => m.group(1)!.split('').map(_digitToSuperScript).join(''),
    );
  }

  void _updateFilteredPolys() {
    final int p = fieldOrder.value;
    List<StandardPoly> valid = [];

    for (var data in _standardPolys) {
      if (data.poly.isEmpty) {
        valid.add(data);
        continue;
      }
      try {
        Polynomial f = parsePolynomial(data.poly, p, true, null);
        if (_isIrreducible(f, p)) {
          valid.add(data);
        }
      } catch (_) {}
    }

    setState(() {
      _filteredPolys = valid;
    });
  }

  void _updateOrder(int newOrder) {
    setState(() {
      _isCurrentPrime = _isPrime(newOrder);
    });
    if (newOrder > 1) {
      fieldOrder.value = newOrder;
      _validateModPoly();
      _updateFilteredPolys();
    }
  }

  void _validateModPoly() {
    final modStr = _modController.text;
    final p = fieldOrder.value;

    if (modStr.trim().isEmpty) {
      setState(() {
        _isModPolyValid = true;
        _isModPolyIrreducible = true;
      });
      return;
    }

    try {
      Polynomial f = parsePolynomial(modStr, p, true, null);
      if (f.degree <= 0) {
        setState(() => _isModPolyValid = false);
        return;
      }

      bool irreducible = _isIrreducible(f, p);
      setState(() {
        _isModPolyValid = true;
        _isModPolyIrreducible = irreducible;
      });
    } catch (e) {
      setState(() => _isModPolyValid = false);
    }
  }

  bool _isIrreducible(Polynomial f, int p) {
    if (f.degree <= 1) return true;

    int n = f.degree;
    Polynomial xPoly = Polynomial.fromInts([0, 1], p);
    Polynomial u = xPoly;

    for (int i = 1; i <= n ~/ 2; i++) {
      u = _polyPow(u, p, p, f);

      Polynomial diff = u - xPoly;

      if (diff.isZero) return false;

      List<Polynomial> egcd = Polynomial.extendedGCD(diff, f);
      Polynomial gcd = egcd[0];

      if (gcd.degree > 0) {
        return false;
      }
    }
    return true;
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
        child: SingleChildScrollView(
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
                "Enter a prime number to define the base field size.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pController,
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
                  return ActionChip(
                    avatar: Icon(primeData.icon, size: 16),
                    label: Text("${primeData.value}"),
                    tooltip: primeData.label,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      _pController.text = primeData.value.toString();
                      _updateOrder(primeData.value);
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 48),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Polynomial Mode",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Enable arithmetic with variable x"),
                value: isPolynomialMode.value,
                onChanged: (bool value) {
                  setState(() {
                    isPolynomialMode.value = value;
                  });
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isPolynomialMode,
                builder: (context, isPoly, child) {
                  if (!isPoly) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        "Reducing Polynomial",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Irreducible polynomial for Galois Field arithmetic.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _modController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Modulus Polynomial",
                          prefixIcon: Icon(Icons.functions),
                        ),
                        onChanged: (value) {
                          reducingPolyString.value = value;
                          _validateModPoly();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_modController.text.trim().isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              !_isModPolyValid
                                  ? Icons.error
                                  : _isModPolyIrreducible
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: !_isModPolyValid
                                  ? Colors.redAccent
                                  : _isModPolyIrreducible
                                  ? Colors.green
                                  : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                !_isModPolyValid
                                    ? "Syntax error in polynomial."
                                    : _isModPolyIrreducible
                                    ? "Irreducible! Safe for strict field arithmetic."
                                    : "Reducible! Inverses may not exist (Zero Divisors).",
                                style: TextStyle(
                                  color: !_isModPolyValid
                                      ? Colors.redAccent
                                      : _isModPolyIrreducible
                                      ? Colors.green
                                      : Colors.orangeAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (_filteredPolys.isNotEmpty) ...[
                        const Text(
                          "Valid Irreducible Polynomials for Current Prime",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12.0,
                          runSpacing: 12.0,
                          children: _filteredPolys.map((data) {
                            return ActionChip(
                              avatar: const Icon(Icons.functions, size: 16),
                              label: Text(_formatPoly(data.poly)),
                              tooltip: data.label,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () {
                                _modController.text = data.poly;
                                reducingPolyString.value = data.poly;
                                _validateModPoly();
                              },
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        const Text(
                          "No common irreducible polynomials found for this prime. Try defining your own.",
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  );
                },
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

Polynomial _polyPow(Polynomial base, int exponent, int p, Polynomial? modulus) {
  Polynomial result = Polynomial.fromInts([1], p);
  Polynomial current = base;
  int exp = exponent;

  while (exp > 0) {
    if (exp % 2 == 1) {
      result = result * current;
      if (modulus != null) result = result % modulus;
    }
    current = current * current;
    if (modulus != null) current = current % modulus;
    exp >>= 1;
  }
  return result;
}
