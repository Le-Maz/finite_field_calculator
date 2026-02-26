import 'finite_field.dart';

class Polynomial {
  late final List<FiniteFieldElement> coefficients;

  Polynomial(List<FiniteFieldElement> coeffs) {
    coefficients = _stripLeadingZeros(coeffs);
  }

  Polynomial.zero(int p) : coefficients = [] {
    _p = p;
  }

  Polynomial.fromInts(List<int> ints, int p) {
    final coeffs = ints.map((val) => FiniteFieldElement(val, p)).toList();
    coefficients = _stripLeadingZeros(coeffs);
  }

  int _p = 0;
  int get p {
    if (coefficients.isNotEmpty) {
      return coefficients.first.p;
    }
    return _p;
  }

  int get degree => coefficients.isEmpty ? -1 : coefficients.length - 1;

  bool get isZero => coefficients.isEmpty;

  List<FiniteFieldElement> _stripLeadingZeros(List<FiniteFieldElement> coeffs) {
    int lastNonZero = coeffs.length - 1;
    while (lastNonZero >= 0 && coeffs[lastNonZero].value == 0) {
      lastNonZero--;
    }
    if (lastNonZero < 0) return [];
    return coeffs.sublist(0, lastNonZero + 1);
  }

  void _checkField(Polynomial other) {
    if (!isZero && !other.isZero && p != other.p) {
      throw ArgumentError('Polynomials must be over the same finite field.');
    }
  }

  Polynomial operator +(Polynomial other) {
    _checkField(other);
    final currentP = isZero ? other.p : p;

    int maxLength = coefficients.length > other.coefficients.length
        ? coefficients.length
        : other.coefficients.length;

    List<FiniteFieldElement> result = [];
    for (int i = 0; i < maxLength; i++) {
      FiniteFieldElement a = i < coefficients.length
          ? coefficients[i]
          : FiniteFieldElement(0, currentP);
      FiniteFieldElement b = i < other.coefficients.length
          ? other.coefficients[i]
          : FiniteFieldElement(0, currentP);
      result.add(a + b);
    }
    return Polynomial(result);
  }

  Polynomial operator -(Polynomial other) {
    _checkField(other);
    final currentP = isZero ? other.p : p;

    int maxLength = coefficients.length > other.coefficients.length
        ? coefficients.length
        : other.coefficients.length;

    List<FiniteFieldElement> result = [];
    for (int i = 0; i < maxLength; i++) {
      FiniteFieldElement a = i < coefficients.length
          ? coefficients[i]
          : FiniteFieldElement(0, currentP);
      FiniteFieldElement b = i < other.coefficients.length
          ? other.coefficients[i]
          : FiniteFieldElement(0, currentP);
      result.add(a - b);
    }
    return Polynomial(result);
  }

  Polynomial operator *(Polynomial other) {
    _checkField(other);
    if (isZero || other.isZero) {
      return Polynomial.zero(isZero ? other.p : p);
    }

    final currentP = p;
    int newDegree = degree + other.degree;
    List<FiniteFieldElement> result = List.generate(
      newDegree + 1,
      (_) => FiniteFieldElement(0, currentP),
    );

    for (int i = 0; i <= degree; i++) {
      for (int j = 0; j <= other.degree; j++) {
        result[i + j] =
            result[i + j] + (coefficients[i] * other.coefficients[j]);
      }
    }
    return Polynomial(result);
  }

  List<Polynomial> divMod(Polynomial other) {
    if (other.isZero) throw ArgumentError("Division by zero polynomial");
    _checkField(other);

    Polynomial q = Polynomial.zero(p);
    Polynomial r = this;

    while (!r.isZero && r.degree >= other.degree) {
      int degDiff = r.degree - other.degree;

      FiniteFieldElement leadR = r.coefficients[r.degree];
      FiniteFieldElement leadOther = other.coefficients[other.degree];
      FiniteFieldElement coeff = leadR * leadOther.inverse();

      List<FiniteFieldElement> termCoeffs = List.generate(
        degDiff + 1,
        (i) => FiniteFieldElement(0, p),
      );
      termCoeffs[degDiff] = coeff;
      Polynomial term = Polynomial(termCoeffs);

      q = q + term;
      r = r - (term * other);
    }
    return [q, r];
  }

  Polynomial operator %(Polynomial other) => divMod(other)[1];
  Polynomial operator ~/(Polynomial other) => divMod(other)[0];

  static List<Polynomial> extendedGCD(Polynomial a, Polynomial b) {
    if (a.p != b.p && !a.isZero && !b.isZero) {
      throw ArgumentError("Polynomials must be over the same field.");
    }
    int fieldP = a.isZero ? b.p : a.p;

    Polynomial x0 = Polynomial.fromInts([1], fieldP);
    Polynomial x1 = Polynomial.zero(fieldP);
    Polynomial y0 = Polynomial.zero(fieldP);
    Polynomial y1 = Polynomial.fromInts([1], fieldP);

    Polynomial r0 = a;
    Polynomial r1 = b;

    while (!r1.isZero) {
      var divModRes = r0.divMod(r1);
      Polynomial q = divModRes[0];
      Polynomial r2 = divModRes[1];

      r0 = r1;
      r1 = r2;

      Polynomial x2 = x0 - (q * x1);
      x0 = x1;
      x1 = x2;

      Polynomial y2 = y0 - (q * y1);
      y0 = y1;
      y1 = y2;
    }

    if (!r0.isZero) {
      FiniteFieldElement leadInverse = r0.coefficients.last.inverse();
      Polynomial leadInvPoly = Polynomial([leadInverse]);
      r0 = r0 * leadInvPoly;
      x0 = x0 * leadInvPoly;
      y0 = y0 * leadInvPoly;
    }

    return [r0, x0, y0];
  }

  Polynomial inverseMod(Polynomial modulus) {
    var egcd = extendedGCD(this, modulus);
    Polynomial gcd = egcd[0];
    Polynomial inv = egcd[1];

    if (gcd.degree > 0) {
      throw Exception("Polynomial is not invertible.");
    }
    return inv % modulus;
  }

  @override
  String toString() {
    if (isZero) return '0';

    StringBuffer buffer = StringBuffer();
    for (int i = degree; i >= 0; i--) {
      int val = coefficients[i].value;
      if (val == 0) continue;

      if (buffer.isNotEmpty) {
        buffer.write(' + ');
      }

      if (i == 0) {
        buffer.write(val);
      } else if (i == 1) {
        if (val == 1) {
          buffer.write('x');
        } else {
          buffer.write('${val}x');
        }
      } else {
        if (val == 1) {
          buffer.write('x^$i');
        } else {
          buffer.write('${val}x^$i');
        }
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Polynomial) return false;
    if (isZero && other.isZero) return true;
    if (degree != other.degree || p != other.p) return false;

    for (int i = 0; i <= degree; i++) {
      if (coefficients[i] != other.coefficients[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = p.hashCode;
    for (var coeff in coefficients) {
      hash ^= coeff.hashCode;
    }
    return hash;
  }
}
