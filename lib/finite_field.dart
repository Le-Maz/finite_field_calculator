class FiniteFieldElement {
  final int value;
  final int p;

  FiniteFieldElement(int val, this.p) : value = (val % p + p) % p;

  FiniteFieldElement operator +(FiniteFieldElement other) {
    _checkField(other);
    return FiniteFieldElement(value + other.value, p);
  }

  FiniteFieldElement operator -(FiniteFieldElement other) {
    _checkField(other);
    return FiniteFieldElement(value - other.value, p);
  }

  FiniteFieldElement operator *(FiniteFieldElement other) {
    _checkField(other);
    return FiniteFieldElement((value * other.value) % p, p);
  }

  FiniteFieldElement pow(int exponent) {
    return FiniteFieldElement(_modPow(value, exponent, p), p);
  }

  FiniteFieldElement inverse() {
    if (value == 0) throw ArgumentError('Division by zero');
    return FiniteFieldElement(_extendedGCD(value, p), p);
  }

  void _checkField(FiniteFieldElement other) {
    if (p != other.p) {
      throw ArgumentError('Elements must belong to the same finite field.');
    }
  }

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiniteFieldElement &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          p == other.p;

  @override
  int get hashCode => value.hashCode ^ p.hashCode;

  static int _modPow(int base, int exponent, int modulus) {
    if (modulus == 1) return 0;
    int result = 1;
    base = base % modulus;

    if (exponent < 0) {
      base = _extendedGCD(base, modulus);
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

  static int _extendedGCD(int a, int m) {
    int m0 = m, t, q;
    int x0 = 0, x1 = 1;

    if (m == 1) return 0;

    while (a > 1) {
      if (m == 0) throw ArgumentError();
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
}
