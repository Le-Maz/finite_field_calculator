import 'package:finite_field_calculator/polynomial.dart';

bool isPrime(int n) {
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

Polynomial parsePolynomial(
  String expression,
  int p,
  bool isPoly,
  Polynomial? modulus,
) {
  String processed = expression
      .replaceAllMapped(RegExp(r'(\d)(x)'), (m) => '${m[1]}×${m[2]}')
      .replaceAllMapped(RegExp(r'(x)(\d)'), (m) => '${m[1]}×${m[2]}')
      .replaceAllMapped(RegExp(r'(\))([x\d])'), (m) => '${m[1]}×${m[2]}')
      .replaceAllMapped(RegExp(r'([x\d])(\()'), (m) => '${m[1]}×${m[2]}');

  final tokens = _tokenize(processed);
  final rpn = _toRPN(tokens);
  return _evaluateRPNToPoly(rpn, p, isPoly, modulus);
}

List<String> _tokenize(String expression) {
  final regex = RegExp(r'(\d+|x|[+\-×()^]|⁻¹)');
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
    if (int.tryParse(token) != null || token == 'x') {
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

Polynomial _evaluateRPNToPoly(
  List<String> tokens,
  int p,
  bool isPoly,
  Polynomial? modulus,
) {
  List<dynamic> stack = [];

  for (var token in tokens) {
    if (int.tryParse(token) != null) {
      stack.add(int.parse(token));
    } else if (token == 'x') {
      if (!isPoly) throw Exception("Polynomial mode is disabled");
      stack.add(Polynomial.fromInts([0, 1], p));
    } else if (token == '⁻¹') {
      if (stack.isEmpty) throw Exception();
      dynamic a = stack.removeLast();
      Polynomial polyA = a is int
          ? Polynomial.fromInts([a], p)
          : a as Polynomial;

      if (!isPoly) {
        if (polyA.degree > 0) {
          throw Exception("Cannot invert poly in scalar mode");
        }
        if (polyA.isZero) throw Exception("Division by zero");
        int val = polyA.coefficients[0]
            .inverse()
            .value; // Assuming an inverse() method exists on the coefficient
        stack.add(Polynomial.fromInts([val], p));
      } else {
        if (modulus == null || modulus.isZero) {
          throw Exception("Reducing polynomial is required for inversion");
        }
        stack.add(polyA.inverseMod(modulus)); // Assuming inverseMod exists
      }
    } else {
      if (stack.length < 2) throw Exception();
      dynamic b = stack.removeLast();
      dynamic a = stack.removeLast();
      Polynomial res = Polynomial.zero(p);

      if (token == '^') {
        Polynomial polyA = a is int
            ? Polynomial.fromInts([a], p)
            : a as Polynomial;
        int exp;
        if (b is int) {
          exp = b;
        } else {
          Polynomial polyB = b as Polynomial;
          if (polyB.degree > 0) throw Exception("Exponent must be a scalar");
          exp = polyB.isZero ? 0 : polyB.coefficients[0].value;
        }
        res = polyPow(polyA, exp, p, modulus);
      } else {
        Polynomial polyA = a is int
            ? Polynomial.fromInts([a], p)
            : a as Polynomial;
        Polynomial polyB = b is int
            ? Polynomial.fromInts([b], p)
            : b as Polynomial;

        switch (token) {
          case '+':
            res = polyA + polyB;
            break;
          case '-':
            res = polyA - polyB;
            break;
          case '×':
            res = polyA * polyB;
            break;
        }
      }

      if (isPoly && modulus != null && token != '^') {
        res = res % modulus;
      }
      stack.add(res);
    }
  }

  if (stack.isEmpty) return Polynomial.zero(p);
  dynamic finalRes = stack.first;
  return finalRes is int
      ? Polynomial.fromInts([finalRes], p)
      : finalRes as Polynomial;
}

Polynomial polyPow(Polynomial base, int exponent, int p, Polynomial? modulus) {
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
