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
  final tokens = _tokenize(expression);
  final withUnary = _handleUnaryMinus(tokens);
  final processedTokens = _insertImplicitMultiplication(withUnary);
  final rpn = _toRPN(processedTokens);
  return _evaluateRPNToPoly(rpn, p, isPoly, modulus);
}

List<String> _tokenize(String expression) {
  final regex = RegExp(r'(\d+|x|[+\-×()^])');
  return regex.allMatches(expression).map((e) => e.group(0)!).toList();
}

List<String> _handleUnaryMinus(List<String> tokens) {
  List<String> result = [];
  for (int i = 0; i < tokens.length; i++) {
    if (tokens[i] == '-') {
      bool isUnary =
          i == 0 || ['+', '-', '×', '^', '('].contains(tokens[i - 1]);
      if (isUnary) {
        result.add('~');
        continue;
      }
    }
    result.add(tokens[i]);
  }
  return result;
}

List<String> _insertImplicitMultiplication(List<String> tokens) {
  List<String> result = [];

  for (int i = 0; i < tokens.length; i++) {
    result.add(tokens[i]);

    if (i < tokens.length - 1) {
      String curr = tokens[i];
      String next = tokens[i + 1];

      bool currIsLeftOperand = RegExp(r'^(\d+|x|\))$').hasMatch(curr);
      bool nextIsRightOperand = RegExp(r'^(\d+|x|\(|~)$').hasMatch(next);

      if (currIsLeftOperand && nextIsRightOperand) {
        result.add('×');
      }
    }
  }

  return result;
}

int _getPrecedence(String op) {
  if (op == '+' || op == '-') return 1;
  if (op == '×') return 2;
  if (op == '~') return 3;
  if (op == '^') return 4;
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
    } else if (token == '~') {
      stack.add(token);
    } else {
      while (stack.isNotEmpty && stack.last != '(') {
        int precTop = _getPrecedence(stack.last);
        int precToken = _getPrecedence(token);
        bool isRightAssoc = token == '^';

        if ((!isRightAssoc && precTop >= precToken) ||
            (isRightAssoc && precTop > precToken)) {
          output.add(stack.removeLast());
        } else {
          break;
        }
      }
      stack.add(token);
    }
  }
  while (stack.isNotEmpty) {
    output.add(stack.removeLast());
  }
  return output;
}

int _modInverse(int a, int m) {
  int m0 = m, t, q;
  int x0 = 0, x1 = 1;
  if (m == 1) return 0;
  while (a > 1) {
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
      if (!isPoly) throw ArgumentError("Polynomial mode is disabled");
      stack.add(Polynomial.fromInts([0, 1], p));
    } else if (token == '~') {
      if (stack.isEmpty) throw ArgumentError();
      dynamic a = stack.removeLast();

      if (a is int) {
        stack.add(-a);
      } else {
        Polynomial polyA = a as Polynomial;
        stack.add(Polynomial.zero(p) - polyA);
      }
    } else if (token == '⁻¹') {
      if (stack.isEmpty) throw ArgumentError();
      dynamic a = stack.removeLast();

      if (a is int) {
        stack.add(_modInverse(a, p));
      } else {
        Polynomial polyA = a as Polynomial;
        if (!isPoly) {
          if (polyA.degree > 0) {
            throw ArgumentError("Cannot invert poly in scalar mode");
          }
          if (polyA.isZero) throw ArgumentError("Division by zero");
          int val = polyA.coefficients.isEmpty
              ? 0
              : polyA.coefficients[0].value;
          stack.add(Polynomial.fromInts([_modInverse(val, p)], p));
        } else {
          if (modulus == null || modulus.isZero) {
            throw ArgumentError(
              "Reducing polynomial is required for inversion",
            );
          }
          stack.add(polyA.inverseMod(modulus));
        }
      }
    } else {
      if (stack.length < 2) throw Exception();
      dynamic b = stack.removeLast();
      dynamic a = stack.removeLast();

      if (token == '^') {
        Polynomial polyA = a is int
            ? Polynomial.fromInts([a], p)
            : a as Polynomial;
        int exp;
        if (b is int) {
          exp = b;
        } else {
          Polynomial polyB = b as Polynomial;
          if (polyB.degree > 0) {
            throw ArgumentError("Exponent must be a scalar");
          }
          exp = polyB.isZero ? 0 : polyB.coefficients[0].value;
        }
        stack.add(polyPow(polyA, exp, p, isPoly, modulus));
      } else {
        if (a is int && b is int) {
          int resInt;
          switch (token) {
            case '+':
              resInt = a + b;
              break;
            case '-':
              resInt = a - b;
              break;
            case '×':
              resInt = a * b;
              break;
            default:
              throw ArgumentError("Unknown operator");
          }
          stack.add(resInt);
        } else {
          Polynomial polyA = a is int
              ? Polynomial.fromInts([a], p)
              : a as Polynomial;
          Polynomial polyB = b is int
              ? Polynomial.fromInts([b], p)
              : b as Polynomial;
          Polynomial res = Polynomial.zero(p);

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

          if (isPoly && modulus != null) {
            res = res % modulus;
          }
          stack.add(res);
        }
      }
    }
  }

  if (stack.isEmpty) return Polynomial.zero(p);
  dynamic finalRes = stack.first;
  return finalRes is int
      ? Polynomial.fromInts([finalRes], p)
      : finalRes as Polynomial;
}

Polynomial polyPow(
  Polynomial base,
  int exponent,
  int p,
  bool isPoly,
  Polynomial? modulus,
) {
  Polynomial current = base;
  int exp = exponent;

  if (exp < 0) {
    if (isPoly) {
      if (modulus == null || modulus.isZero) {
        throw ArgumentError(
          "Reducing polynomial required for negative exponents",
        );
      }
      current = current.inverseMod(modulus);
    } else {
      if (current.degree > 0) {
        throw ArgumentError("Cannot invert poly in scalar mode");
      }
      if (current.isZero) throw ArgumentError("Division by zero");
      int baseInt = current.coefficients.isEmpty
          ? 0
          : current.coefficients[0].value;
      int inv = _modInverse(baseInt, p);
      current = Polynomial.fromInts([inv], p);
    }
    exp = -exp;
  }

  Polynomial result = Polynomial.fromInts([1], p);

  while (exp > 0) {
    if (exp % 2 == 1) {
      result = result * current;
      if (isPoly && modulus != null) result = result % modulus;
    }
    current = current * current;
    if (isPoly && modulus != null) current = current % modulus;
    exp >>= 1;
  }
  return result;
}
