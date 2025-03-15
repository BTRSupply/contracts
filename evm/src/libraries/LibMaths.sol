// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Helper library for type casting
library AsCast {

  error ValueOutOfCastRange();

  function toInt256(uint256 value) internal pure returns (int256) {
    // If value > INT256_MAX, it will revert
    if (value > uint256(type(int256).max)) revert ValueOutOfCastRange();
    return int256(value);
  }

  function toUint256(int256 value) internal pure returns (uint256) {
    // If value < 0, it will revert
    if (value < 0) revert ValueOutOfCastRange();
    return uint256(value);
  }
}

library LibMaths {
  using AsCast for uint256;
  using AsCast for int256;

  // Add enum for rounding directions to maintain compatibility
  enum Rounding {
    DOWN,
    UP
  }

  uint256 internal constant WAD = 1e18;
  uint256 internal constant RAY = 1e27;
  uint256 internal constant BP_BASIS = 100_00;
  uint256 internal constant PRECISION_BP_BASIS = BP_BASIS ** 2;
  uint256 internal constant SEC_PER_YEAR = 31_556_952;

  function subBpDown(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, BP_BASIS - basisPoints, BP_BASIS);
    }
  }

  function subBpUp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivUp(amount, BP_BASIS - basisPoints, BP_BASIS);
    }
  }

  function addBpDown(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, BP_BASIS + basisPoints, BP_BASIS);
    }
  }

  function addBpUp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivUp(amount, BP_BASIS + basisPoints, BP_BASIS);
    }
  }

  function bpDown(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, basisPoints, BP_BASIS);
    }
  }
  
  function pbpDown(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, basisPoints, PRECISION_BP_BASIS);
    }
  }

  function bpUp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivUp(amount, basisPoints, BP_BASIS);
    }
  }

  function pbpUp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivUp(amount, basisPoints, PRECISION_BP_BASIS);
    }
  }

  function revBpDown(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, basisPoints, BP_BASIS - basisPoints);
    }
  }

  function revBpUp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivUp(amount, basisPoints, BP_BASIS - basisPoints);
    }
  }

  function revAddBp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, BP_BASIS, BP_BASIS - basisPoints);
    }
  }

  function revSubBp(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
    unchecked {
      return mulDivDown(amount, BP_BASIS, BP_BASIS + basisPoints);
    }
  }

  function toWad(uint256 bps) internal pure returns (uint256) {
    unchecked {
      return bps * WAD / BP_BASIS;
    }
  }

  function toBps(uint256 wad) internal pure returns (uint256) {
    unchecked {
      return wad * BP_BASIS / WAD;
    }
  }

  function mulDivDown(
    uint256 a,
    uint256 b,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly {
      let mm := mulmod(a, b, not(0))
      prod0 := mul(a, b)
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 == 0) {
      require(denominator > 0);
      assembly {
        result := div(prod0, denominator)
      }
      return result;
    }

    require(denominator > prod1);

    uint256 remainder;
    assembly {
      remainder := mulmod(a, b, denominator)
    }
    assembly {
      prod1 := sub(prod1, gt(remainder, prod0))
      prod0 := sub(prod0, remainder)
    }

    uint256 twos = denominator & (~denominator + 1);
    assembly {
      denominator := div(denominator, twos)
    }

    assembly {
      prod0 := div(prod0, twos)
    }
    assembly {
      twos := add(div(sub(0, twos), twos), 1)
    }
    prod0 |= prod1 * twos;

    uint256 inv = (3 * denominator) ^ 2;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;

    result = prod0 * inv;
    return result;
  }

  function mulDivUp(
    uint256 a,
    uint256 b,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    result = mulDivDown(a, b, denominator);
    if (mulmod(a, b, denominator) > 0) {
      require(result < type(uint256).max);
      result++;
    }
  }

  function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    assembly {
      z := add(div(x, y), gt(mod(x, y), 0))
    }
  }

  function diff(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a > b ? a - b : b - a;
    }
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }


  function approxEq(uint256 a, uint256 b, uint256 eps) internal pure returns (bool) {
    return mulDown(b, WAD - eps) <= a && a <= mulDown(b, WAD + eps);
  }

  function approxGt(uint256 a, uint256 b, uint256 eps) internal pure returns (bool) {
    return a >= b && a <= mulDown(b, WAD + eps);
  }

  function approxLt(uint256 a, uint256 b, uint256 eps) internal pure returns (bool) {
    return a <= b && a >= mulDown(b, WAD - eps);
  }

  function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      uint256 c = a + b;
      if (c < a) return (false, 0);
      return (true, c);
    }
  }

  function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b > a) return (false, 0);
      return (true, a - b);
    }
  }

  function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (a == 0) return (true, 0);
      uint256 c = a * b;
      if (c / a != b) return (false, 0);
      return (true, c);
    }
  }

  function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b == 0) return (false, 0);
      return (true, a / b);
    }
  }

  function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
      if (b == 0) return (false, 0);
      return (true, a % b);
    }
  }

  function average(uint256 a, uint256 b) internal pure returns (uint256) {
    return (a & b) + (a ^ b) / 2;
  }

  function within(uint256 value, uint256 _min, uint256 _max) internal pure returns (bool) {
    unchecked {
      return value >= _min && value <= _max;
    }
  }

  function within(uint32 value, uint32 _min, uint32 _max) internal pure returns (bool) {
    unchecked {
      return value >= _min && value <= _max;
    }
  }

  function within(uint64 value, uint64 _min, uint64 _max) internal pure returns (bool) {
    unchecked {
      return value >= _min && value <= _max;
    }
  }

  function within(int256 value, int256 _min, int256 _max) internal pure returns (bool) {
    unchecked {
      return value >= _min && value <= _max;
    }
  }

  function within32(uint32 value, uint256 _min, uint256 _max) internal pure returns (bool) {
    unchecked {
      return uint256(value) >= _min && uint256(value) <= _max;
    }
  }

  function within64(uint64 value, uint256 _min, uint256 _max) internal pure returns (bool) {
    unchecked {
      return uint256(value) >= _min && uint256(value) <= _max;
    }
  }

  function diffWithin(uint256 a, uint256 b, uint256 val) internal pure returns (bool) {
    return diff(a, b) <= val;
  }

  function diffWithin1(uint256 a, uint256 b) internal pure returns (bool) {
    return diffWithin(a, b, 1);
  }

  function subMax0(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a > b ? a - b : 0;
    }
  }

  function subNoNeg(int256 a, int256 b) internal pure returns (int256) {
    if (a < b) revert AsCast.ValueOutOfCastRange();
    unchecked {
      return a - b;
    }
  }

  function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 product = a * b;
    unchecked {
      return product / 1e18;
    }
  }

  function mulDown(int256 a, int256 b) internal pure returns (int256) {
    int256 product = a * b;
    unchecked {
      return product / 1e18;
    }
  }

  function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 aInflated = a * 1e18;
    unchecked {
      return aInflated / b;
    }
  }

  function divDown(int256 a, int256 b) internal pure returns (int256) {
    int256 aInflated = a * 1e18;
    unchecked {
      return aInflated / b;
    }
  }

  function rawDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return (a + b - 1) / b;
  }

  function abs(int256 x) internal pure returns (uint256) {
    return x == type(int256).min ? uint256(type(int256).max) + 1 : uint256(x > 0 ? x : -x);
  }

  function neg(int256 x) internal pure returns (int256) {
    return x * -1;
  }

  function neg(uint256 x) internal pure returns (int256) {
    return x.toInt256() * -1;
  }
}
