// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero

    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// node_modules/@hyperlane-xyz/core/contracts/hooks/libs/StandardHookMetadata.sol

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

/**
 * Format of metadata:
 *
 * [0:2] variant
 * [2:34] msg.value
 * [34:66] Gas limit for message (IGP)
 * [66:86] Refund address for message (IGP)
 * [86:] Custom metadata
 */
library StandardHookMetadata {
    struct Metadata {
        uint16 variant;
        uint256 msgValue;
        uint256 gasLimit;
        address refundAddress;
    }

    uint8 private constant VARIANT_OFFSET = 0;
    uint8 private constant MSG_VALUE_OFFSET = 2;
    uint8 private constant GAS_LIMIT_OFFSET = 34;
    uint8 private constant REFUND_ADDRESS_OFFSET = 66;
    uint256 private constant MIN_METADATA_LENGTH = 86;

    uint16 public constant VARIANT = 1;

    /**
     * @notice Returns the variant of the metadata.
     * @param _metadata ABI encoded standard hook metadata.
     * @return variant of the metadata as uint8.
     */
    function variant(bytes calldata _metadata) internal pure returns (uint16) {
        if (_metadata.length < VARIANT_OFFSET + 2) return 0;
        return uint16(bytes2(_metadata[VARIANT_OFFSET:VARIANT_OFFSET + 2]));
    }

    /**
     * @notice Returns the specified value for the message.
     * @param _metadata ABI encoded standard hook metadata.
     * @param _default Default fallback value.
     * @return Value for the message as uint256.
     */
    function msgValue(bytes calldata _metadata, uint256 _default) internal pure returns (uint256) {
        if (_metadata.length < MSG_VALUE_OFFSET + 32) return _default;
        return uint256(bytes32(_metadata[MSG_VALUE_OFFSET:MSG_VALUE_OFFSET + 32]));
    }

    /**
     * @notice Returns the specified gas limit for the message.
     * @param _metadata ABI encoded standard hook metadata.
     * @param _default Default fallback gas limit.
     * @return Gas limit for the message as uint256.
     */
    function gasLimit(bytes calldata _metadata, uint256 _default) internal pure returns (uint256) {
        if (_metadata.length < GAS_LIMIT_OFFSET + 32) return _default;
        return uint256(bytes32(_metadata[GAS_LIMIT_OFFSET:GAS_LIMIT_OFFSET + 32]));
    }

    /**
     * @notice Returns the specified refund address for the message.
     * @param _metadata ABI encoded standard hook metadata.
     * @param _default Default fallback refund address.
     * @return Refund address for the message as address.
     */
    function refundAddress(bytes calldata _metadata, address _default) internal pure returns (address) {
        if (_metadata.length < REFUND_ADDRESS_OFFSET + 20) return _default;
        return address(bytes20(_metadata[REFUND_ADDRESS_OFFSET:REFUND_ADDRESS_OFFSET + 20]));
    }

    /**
     * @notice Returns any custom metadata.
     * @param _metadata ABI encoded standard hook metadata.
     * @return Custom metadata.
     */
    function getCustomMetadata(bytes calldata _metadata) internal pure returns (bytes calldata) {
        if (_metadata.length < MIN_METADATA_LENGTH) return _metadata[0:0];
        return _metadata[MIN_METADATA_LENGTH:];
    }

    /**
     * @notice Formats the specified gas limit and refund address into standard hook metadata.
     * @param _msgValue msg.value for the message.
     * @param _gasLimit Gas limit for the message.
     * @param _refundAddress Refund address for the message.
     * @param _customMetadata Additional metadata to include in the standard hook metadata.
     * @return ABI encoded standard hook metadata.
     */
    function formatMetadata(uint256 _msgValue, uint256 _gasLimit, address _refundAddress, bytes memory _customMetadata)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(VARIANT, _msgValue, _gasLimit, _refundAddress, _customMetadata);
    }

    /**
     * @notice Formats the specified gas limit and refund address into standard hook metadata.
     * @param _msgValue msg.value for the message.
     * @return ABI encoded standard hook metadata.
     */
    function overrideMsgValue(uint256 _msgValue) internal view returns (bytes memory) {
        return formatMetadata(_msgValue, uint256(0), msg.sender, '');
    }

    /**
     * @notice Formats the specified gas limit and refund address into standard hook metadata.
     * @param _gasLimit Gas limit for the message.
     * @return ABI encoded standard hook metadata.
     */
    function overrideGasLimit(uint256 _gasLimit) internal view returns (bytes memory) {
        return formatMetadata(uint256(0), _gasLimit, msg.sender, '');
    }

    /**
     * @notice Formats the specified refund address into standard hook metadata.
     * @param _refundAddress Refund address for the message.
     * @return ABI encoded standard hook metadata.
     */
    function overrideRefundAddress(address _refundAddress) internal pure returns (bytes memory) {
        return formatMetadata(uint256(0), uint256(0), _refundAddress, '');
    }
}

// node_modules/@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol

interface IInterchainSecurityModule {
    enum Types {
        UNUSED,
        ROUTING,
        AGGREGATION,
        LEGACY_MULTISIG,
        MERKLE_ROOT_MULTISIG,
        MESSAGE_ID_MULTISIG,
        NULL, // used with relayer carrying no metadata
        CCIP_READ,
        ARB_L2_TO_L1
    }

    /**
     * @notice Returns an enum that represents the type of security model
     * encoded by this ISM.
     * @dev Relayers infer how to fetch and format metadata.
     */
    function moduleType() external view returns (uint8);

    /**
     * @notice Defines a security model responsible for verifying interchain
     * messages based on the provided metadata.
     * @param _metadata Off-chain metadata provided by a relayer, specific to
     * the security model encoded by the module (e.g. validator signatures)
     * @param _message Hyperlane encoded interchain message
     * @return True if the message was verified
     */
    function verify(bytes calldata _metadata, bytes calldata _message) external returns (bool);
}

interface ISpecifiesInterchainSecurityModule_0 {
    function interchainSecurityModule() external view returns (IInterchainSecurityModule);
}

// node_modules/@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol

interface IMessageRecipient {
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable;
}

// node_modules/@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

interface IPostDispatchHook {
    enum Types {
        UNUSED,
        ROUTING,
        AGGREGATION,
        MERKLE_TREE,
        INTERCHAIN_GAS_PAYMASTER,
        FALLBACK_ROUTING,
        ID_AUTH_ISM,
        PAUSABLE,
        PROTOCOL_FEE,
        LAYER_ZERO_V1,
        RATE_LIMITED,
        ARB_L2_TO_L1
    }

    /**
     * @notice Returns an enum that represents the type of hook
     */
    function hookType() external view returns (uint8);

    /**
     * @notice Returns whether the hook supports metadata
     * @param metadata metadata
     * @return Whether the hook supports metadata
     */
    function supportsMetadata(bytes calldata metadata) external view returns (bool);

    /**
     * @notice Post action after a message is dispatched via the Mailbox
     * @param metadata The metadata required for the hook
     * @param message The message passed from the Mailbox.dispatch() call
     */
    function postDispatch(bytes calldata metadata, bytes calldata message) external payable;

    /**
     * @notice Compute the payment required by the postDispatch call
     * @param metadata The metadata required for the hook
     * @param message The message passed from the Mailbox.dispatch() call
     * @return Quoted payment for the postDispatch call
     */
    function quoteDispatch(bytes calldata metadata, bytes calldata message) external view returns (uint256);
}

// node_modules/@hyperlane-xyz/core/contracts/libs/Indexed.sol

contract Indexed {
    uint256 public immutable deployedBlock;

    constructor() {
        deployedBlock = block.number;
    }
}

// node_modules/@hyperlane-xyz/core/contracts/libs/TypeCasts.sol

library TypeCasts {
    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }
}

// node_modules/@hyperlane-xyz/core/contracts/upgrade/Versioned.sol

/**
 * @title Versioned
 * @notice Version getter for contracts
 *
 */
contract Versioned {
    uint8 public constant VERSION = 3;
}

// node_modules/@openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        (bool success,) = recipient.call{value: amount}('');
        require(success, 'Address: unable to send value, recipient may have reverted');
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, 'Address: low-level call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, 'Address: low-level call with value failed');
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        require(address(this).balance >= value, 'Address: insufficient balance for call');
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, 'Address: low-level static call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage)
        internal
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, 'Address: low-level delegate call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), 'Address: call to non-contract');
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage)
        internal
        pure
        returns (bytes memory)
    {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        (bool success,) = recipient.call{value: amount}('');
        require(success, 'Address: unable to send value, recipient may have reverted');
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, 'Address: low-level call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, 'Address: low-level call with value failed');
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        require(address(this).balance >= value, 'Address: insufficient balance for call');
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, 'Address: low-level static call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage)
        internal
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, 'Address: low-level delegate call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), 'Address: call to non-contract');
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage)
        internal
        pure
        returns (bytes memory)
    {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// src/interfaces/bridge/IDomainRegistry.sol

interface IDomainRegistry {
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidDomain();

    event DomainRegistered(uint32 indexed _domain);
    event DomainDeregistered(uint32 indexed _domain);

    /// @notice Returns set of all registered domains
    /// @return An array of all registered domains
    function domains() external view returns (uint256[] memory);

    /// @notice Checks if a domain is registered
    /// @param _domain The domain to check
    /// @return True if the domain is registered, false otherwise
    function contains(uint32 _domain) external view returns (bool);

    /// @notice Registers a new domain
    /// @dev Only callable by the owner, allows messages to the registered domain
    /// @param _domain The domain to register
    function registerDomain(uint32 _domain) external;

    /// @notice Deregisters a domain
    /// @dev Only callable by the owner, disallows messages to the deregistered domain
    /// @param _domain The domain to deregister
    function deregisterDomain(uint32 _domain) external;
}

// src/libraries/Commands.sol

/// @notice Commands for x-chain interactions
/// @dev Existing commands cannot be modified but new commands can be added
library Commands {
    uint256 public constant NOTIFY = 0x00;
    uint256 public constant NOTIFY_WITHOUT_CLAIM = 0x01;
    uint256 public constant GET_INCENTIVES = 0x02;
    uint256 public constant GET_FEES = 0x03;
    uint256 public constant DEPOSIT = 0x04;
    uint256 public constant WITHDRAW = 0x05;
    uint256 public constant CREATE_GAUGE = 0x06;
    uint256 public constant KILL_GAUGE = 0x07;
    uint256 public constant REVIVE_GAUGE = 0x08;

    uint256 private constant COMMAND_OFFSET = 0;
    uint256 private constant ADDRESS_OFFSET = 1;
    /// @dev Second and Third offset are used in messages with multiple consecutive addresses
    uint256 private constant SECOND_OFFSET = ADDRESS_OFFSET + 20;
    uint256 private constant THIRD_OFFSET = SECOND_OFFSET + 20;
    // Offsets for Create Gauge Command
    uint256 private constant TOKEN0_OFFSET = THIRD_OFFSET + 20;
    uint256 private constant TOKEN1_OFFSET = TOKEN0_OFFSET + 20;
    uint256 private constant POOL_PARAM_OFFSET = TOKEN1_OFFSET + 20;
    // Offsets for Reward Claims
    uint256 private constant LENGTH_OFFSET = THIRD_OFFSET + 32;
    uint256 private constant TOKENS_OFFSET = LENGTH_OFFSET + 1;
    // Offset for Deposit/Withdraw
    uint256 private constant TOKEN_ID_OFFSET = ADDRESS_OFFSET + 20 + 32;
    uint256 private constant TIMESTAMP_OFFSET = TOKEN_ID_OFFSET + 32;
    // Offset for Send Token
    uint256 private constant AMOUNT_OFFSET = COMMAND_OFFSET + 20;
    uint256 private constant TOKEN_ID_WITHOUT_COMMAND_OFFSET = AMOUNT_OFFSET + 32;

    /// @notice Returns the command encoded in the message
    /// @dev Assumes message is encoded as (command, ...)
    /// @param _message The message to be decoded
    function command(bytes calldata _message) internal pure returns (uint256) {
        return uint256(uint8(bytes1(_message[COMMAND_OFFSET:COMMAND_OFFSET + 1])));
    }

    /// @notice Returns the address encoded in the message
    /// @dev Assumes message is encoded as (command, address, ...)
    /// @param _message The message to be decoded
    function toAddress(bytes calldata _message) internal pure returns (address) {
        return address(bytes20(_message[ADDRESS_OFFSET:ADDRESS_OFFSET + 20]));
    }

    /// @notice Returns the message without the encoded command
    /// @dev Assumes message is encoded as (command, message)
    /// @param _message The message to be decoded
    function messageWithoutCommand(bytes calldata _message) internal pure returns (bytes calldata) {
        return bytes(_message[COMMAND_OFFSET + 1:]);
    }

    /// @notice Returns the amount encoded in the message
    /// @dev Assumes message is encoded as (command, amount, ...)
    /// @param _message The message to be decoded
    function amount(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[SECOND_OFFSET:SECOND_OFFSET + 32]));
    }

    /// @notice Returns the amount, tokenId and timestamp encoded in the message
    /// @dev Assumes message is encoded as (command, amount, tokenId, timestamp, ...)
    /// @param _message The message to be decoded
    function voteParams(bytes calldata _message) internal pure returns (uint256, uint256, uint256) {
        return (
            uint256(bytes32(_message[SECOND_OFFSET:SECOND_OFFSET + 32])),
            uint256(bytes32(_message[TOKEN_ID_OFFSET:TIMESTAMP_OFFSET])),
            uint256(uint40(bytes5(_message[TIMESTAMP_OFFSET:TIMESTAMP_OFFSET + 5])))
        );
    }

    /// @notice Returns the parameters necessary for gauge creation, encoded in the message
    /// @dev Assumes message is encoded as (command, address, address, address, address, uint24)
    /// @param _message The message to be decoded
    function createGaugeParams(bytes calldata _message)
        internal
        pure
        returns (address, address, address, address, address, uint24)
    {
        return (
            address(bytes20(_message[ADDRESS_OFFSET:ADDRESS_OFFSET + 20])),
            address(bytes20(_message[SECOND_OFFSET:SECOND_OFFSET + 20])),
            address(bytes20(_message[THIRD_OFFSET:THIRD_OFFSET + 20])),
            address(bytes20(_message[TOKEN0_OFFSET:TOKEN0_OFFSET + 20])),
            address(bytes20(_message[TOKEN1_OFFSET:TOKEN1_OFFSET + 20])),
            uint24(bytes3(_message[POOL_PARAM_OFFSET:POOL_PARAM_OFFSET + 3]))
        );
    }

    /// @notice Returns the owner encoded in the message
    /// @dev Assumes message is encoded as (command, address, owner, ...)
    /// @param _message The message to be decoded
    function owner(bytes calldata _message) internal pure returns (address) {
        return address(bytes20(_message[SECOND_OFFSET:SECOND_OFFSET + 20]));
    }

    /// @notice Returns the tokenId encoded in a reward claiming message
    /// @dev Assumes message is encoded as (command, address, tokenId, ...)
    /// @param _message The message to be decoded
    function tokenId(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[THIRD_OFFSET:THIRD_OFFSET + 32]));
    }

    /// @notice Returns the token addresses encoded in the message
    /// @dev Assumes message has length and token addresses encoded
    /// @param _message The message to be decoded
    function tokens(bytes calldata _message) internal pure returns (address[] memory _tokens) {
        uint256 length = uint8(bytes1(_message[LENGTH_OFFSET:LENGTH_OFFSET + 1]));

        _tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _tokens[i] =
                address(uint160(uint256(bytes32(_message[TOKENS_OFFSET + (i * 32):TOKENS_OFFSET + ((i + 1) * 32)]))));
        }
    }

    // Token Bridge

    // Send Token - (address, uint256)
    uint256 public constant SEND_TOKEN_LENGTH = 52;
    // Send Token and Lock - (address, uint256, uint256)
    uint256 public constant SEND_TOKEN_AND_LOCK_LENGTH = 84;

    /// @notice Returns the recipient and amount encoded in the message
    /// @dev Assumes no command is encoded and message is encoded as (address, amount)
    /// @param _message The message to be decoded
    function recipientAndAmount(bytes calldata _message) internal pure returns (address, uint256) {
        return (
            address(bytes20(_message[COMMAND_OFFSET:COMMAND_OFFSET + 20])),
            uint256(bytes32(_message[AMOUNT_OFFSET:AMOUNT_OFFSET + 32]))
        );
    }

    /// @notice Returns the recipient, amount and tokenId encoded in the message
    /// @dev Assumes no command is encoded and message is encoded as (address, amount, tokenId)
    /// @param _message The message to be decoded
    function sendTokenAndLockParams(bytes calldata _message) internal pure returns (address, uint256, uint256) {
        return (
            address(bytes20(_message[COMMAND_OFFSET:COMMAND_OFFSET + 20])),
            uint256(bytes32(_message[AMOUNT_OFFSET:AMOUNT_OFFSET + 32])),
            uint256(bytes32(_message[TOKEN_ID_WITHOUT_COMMAND_OFFSET:TOKEN_ID_WITHOUT_COMMAND_OFFSET + 32]))
        );
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// node_modules/@hyperlane-xyz/core/contracts/libs/Message.sol

/**
 * @title Hyperlane Message Library
 * @notice Library for formatted messages used by Mailbox
 *
 */
library Message {
    using TypeCasts for bytes32;

    uint256 private constant VERSION_OFFSET = 0;
    uint256 private constant NONCE_OFFSET = 1;
    uint256 private constant ORIGIN_OFFSET = 5;
    uint256 private constant SENDER_OFFSET = 9;
    uint256 private constant DESTINATION_OFFSET = 41;
    uint256 private constant RECIPIENT_OFFSET = 45;
    uint256 private constant BODY_OFFSET = 77;

    /**
     * @notice Returns formatted (packed) Hyperlane message with provided fields
     * @dev This function should only be used in memory message construction.
     * @param _version The version of the origin and destination Mailboxes
     * @param _nonce A nonce to uniquely identify the message on its origin chain
     * @param _originDomain Domain of origin chain
     * @param _sender Address of sender as bytes32
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of recipient on destination chain as bytes32
     * @param _messageBody Raw bytes of message body
     * @return Formatted message
     */
    function formatMessage(
        uint8 _version,
        uint32 _nonce,
        uint32 _originDomain,
        bytes32 _sender,
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes calldata _messageBody
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(_version, _nonce, _originDomain, _sender, _destinationDomain, _recipient, _messageBody);
    }

    /**
     * @notice Returns the message ID.
     * @param _message ABI encoded Hyperlane message.
     * @return ID of `_message`
     */
    function id(bytes memory _message) internal pure returns (bytes32) {
        return keccak256(_message);
    }

    /**
     * @notice Returns the message version.
     * @param _message ABI encoded Hyperlane message.
     * @return Version of `_message`
     */
    function version(bytes calldata _message) internal pure returns (uint8) {
        return uint8(bytes1(_message[VERSION_OFFSET:NONCE_OFFSET]));
    }

    /**
     * @notice Returns the message nonce.
     * @param _message ABI encoded Hyperlane message.
     * @return Nonce of `_message`
     */
    function nonce(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[NONCE_OFFSET:ORIGIN_OFFSET]));
    }

    /**
     * @notice Returns the message origin domain.
     * @param _message ABI encoded Hyperlane message.
     * @return Origin domain of `_message`
     */
    function origin(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[ORIGIN_OFFSET:SENDER_OFFSET]));
    }

    /**
     * @notice Returns the message sender as bytes32.
     * @param _message ABI encoded Hyperlane message.
     * @return Sender of `_message` as bytes32
     */
    function sender(bytes calldata _message) internal pure returns (bytes32) {
        return bytes32(_message[SENDER_OFFSET:DESTINATION_OFFSET]);
    }

    /**
     * @notice Returns the message sender as address.
     * @param _message ABI encoded Hyperlane message.
     * @return Sender of `_message` as address
     */
    function senderAddress(bytes calldata _message) internal pure returns (address) {
        return sender(_message).bytes32ToAddress();
    }

    /**
     * @notice Returns the message destination domain.
     * @param _message ABI encoded Hyperlane message.
     * @return Destination domain of `_message`
     */
    function destination(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[DESTINATION_OFFSET:RECIPIENT_OFFSET]));
    }

    /**
     * @notice Returns the message recipient as bytes32.
     * @param _message ABI encoded Hyperlane message.
     * @return Recipient of `_message` as bytes32
     */
    function recipient(bytes calldata _message) internal pure returns (bytes32) {
        return bytes32(_message[RECIPIENT_OFFSET:BODY_OFFSET]);
    }

    /**
     * @notice Returns the message recipient as address.
     * @param _message ABI encoded Hyperlane message.
     * @return Recipient of `_message` as address
     */
    function recipientAddress(bytes calldata _message) internal pure returns (address) {
        return recipient(_message).bytes32ToAddress();
    }

    /**
     * @notice Returns the message body.
     * @param _message ABI encoded Hyperlane message.
     * @return Body of `_message`
     */
    function body(bytes calldata _message) internal pure returns (bytes calldata) {
        return bytes(_message[BODY_OFFSET:]);
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            'Initializable: contract is already initialized'
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, 'Initializable: contract is already initialized');
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, 'Initializable: contract is not initializing');
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, 'Initializable: contract is initializing');
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// src/interfaces/bridge/ITokenBridge.sol

interface ITokenBridge {
    error NotBridge();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();

    event HookSet(address indexed _newHook);
    event SentMessage(
        uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message, string _metadata
    );

    /// @notice Max gas limit for token bridging transactions
    /// @dev Can set a different gas limit by using a custom hook
    function GAS_LIMIT() external view returns (uint256);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the hook contract used after dispatching a message
    /// @dev If set to zero address, default hook will be used instead
    function hook() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);

    /// @notice Sets the address of the hook contract that will be used in bridging
    /// @dev Can use default hook by setting to zero address
    /// @param _hook The address of the new hook contract
    function setHook(address _hook) external;

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// @dev If bridging from/to Root, ERC20 tokens are wrapped into xERC20 for bridging and unwrapped back when received.
    /// @dev Refunds go to msg.sender
    /// @param _recipient The address of the recipient on the destination chain
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _domain The domain of the destination chain
    function sendToken(address _recipient, uint256 _amount, uint32 _domain) external payable;

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// @dev If bridging from/to Root, ERC20 tokens are wrapped into xERC20 for bridging and unwrapped back when received.
    /// @dev Refunds go to the specified _refundAddress
    /// @param _recipient The address of the recipient on the destination chain
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _domain The domain of the destination chain
    /// @param _refundAddress The address to send the excess eth to
    function sendToken(address _recipient, uint256 _amount, uint32 _domain, address _refundAddress) external payable;
}

// src/interfaces/bridge/hyperlane/IHLHandler.sol

interface IHLHandler is IMessageRecipient {
    error NotMailbox();
    error NotRoot();

    event ReceivedMessage(uint32 indexed _origin, bytes32 indexed _sender, uint256 _value, string _message);

    /// @notice Callback function used by the mailbox contract to handle incoming messages
    /// @param _origin The domain from which the message originates
    /// @param _sender The address of the sender of the message
    /// @param _message The message payload
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override;
}

// src/interfaces/external/ISpecifiesInterchainSecurityModule.sol

interface ISpecifiesInterchainSecurityModule_1 {
    event InterchainSecurityModuleSet(address indexed _new);

    // @notice The currently set InterchainSecurityModule.
    function interchainSecurityModule() external view returns (IInterchainSecurityModule);

    // @notice Sets the new InterchainSecurityModule.
    /// @dev Throws if not called by owner.
    /// @param _ism .
    function setInterchainSecurityModule(address _ism) external;
}

// src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol

/// @notice two rate storage slots per rate limit
struct RateLimitMidPoint {
    //// -------------------------------------------- ////
    //// ------------------ SLOT 0 ------------------ ////
    //// -------------------------------------------- ////
    /// @notice the rate per second for this contract
    uint128 rateLimitPerSecond;
    /// @notice the cap of the buffer that can be used at once
    uint112 bufferCap;
    //// -------------------------------------------- ////
    //// ------------------ SLOT 1 ------------------ ////
    //// -------------------------------------------- ////
    /// @notice the last time the buffer was used by the contract
    uint32 lastBufferUsedTime;
    /// @notice the buffer at the timestamp of lastBufferUsedTime
    uint112 bufferStored;
    /// @notice the mid point of the buffer
    uint112 midPoint;
}

/// @title abstract contract for putting a rate limit on how fast a contract
/// can perform an action e.g. Minting
/// @author Elliot Friedman
/// @dev Modified lightly from Zelt at commit 30b2ba0 to update the Solidity Compiler version used
/// Can refer to: (https://github.com/solidity-labs-io/zelt/blob/30b2ba0352422471c03b233d55feddfbdba198a3/src/lib/RateLimitMidpointCommonLibrary.sol)
library RateLimitMidpointCommonLibrary {
    /// @notice event emitted when buffer cap is updated
    event BufferCapUpdate(uint256 oldBufferCap, uint256 newBufferCap);

    /// @notice event emitted when rate limit per second is updated
    event RateLimitPerSecondUpdate(uint256 oldRateLimitPerSecond, uint256 newRateLimitPerSecond);

    /// @notice the amount of action available before hitting the rate limit
    /// @dev replenishes at rateLimitPerSecond per second back to midPoint
    /// @param limit pointer to the rate limit object
    function buffer(RateLimitMidPoint storage limit) public view returns (uint256) {
        uint256 elapsed;
        unchecked {
            elapsed = uint32(block.timestamp) - limit.lastBufferUsedTime;
        }

        uint256 accrued = uint256(limit.rateLimitPerSecond) * elapsed;
        if (limit.bufferStored < limit.midPoint) {
            return Math.min(uint256(limit.bufferStored) + accrued, uint256(limit.midPoint));
        } else if (limit.bufferStored > limit.midPoint) {
            /// past midpoint so subtract accrued off bufferStored back down to midpoint

            /// second part of if statement will not be evaluated if first part is true
            if (accrued > limit.bufferStored || limit.bufferStored - accrued < limit.midPoint) {
                /// if accrued is more than buffer stored, subtracting will underflow,
                /// and we are at the midpoint, so return that
                return limit.midPoint;
            } else {
                return limit.bufferStored - accrued;
            }
        } else {
            /// no change
            return limit.bufferStored;
        }
    }

    /// @notice syncs the buffer to the current time
    /// @dev should be called before any action that
    /// updates buffer cap or rate limit per second
    /// @param limit pointer to the rate limit object
    function sync(RateLimitMidPoint storage limit) internal {
        uint112 newBuffer = uint112(buffer(limit));
        uint32 blockTimestamp = uint32(block.timestamp);

        limit.lastBufferUsedTime = blockTimestamp;
        limit.bufferStored = newBuffer;
    }

    /// @notice set the rate limit per second
    /// @param limit pointer to the rate limit object
    /// @param newRateLimitPerSecond the new rate limit per second
    function setRateLimitPerSecond(RateLimitMidPoint storage limit, uint128 newRateLimitPerSecond) internal {
        sync(limit);
        uint256 oldRateLimitPerSecond = limit.rateLimitPerSecond;
        limit.rateLimitPerSecond = newRateLimitPerSecond;

        emit RateLimitPerSecondUpdate(oldRateLimitPerSecond, newRateLimitPerSecond);
    }

    /// @notice set the buffer cap, but first sync to accrue all rate limits accrued
    /// @param limit pointer to the rate limit object
    /// @param newBufferCap the new buffer cap to set
    function setBufferCap(RateLimitMidPoint storage limit, uint112 newBufferCap) internal {
        sync(limit);

        uint256 oldBufferCap = limit.bufferCap;
        limit.bufferCap = newBufferCap;
        limit.midPoint = uint112(newBufferCap / 2);

        /// if buffer stored is gt buffer cap, then we need set buffer stored to buffer cap
        if (limit.bufferStored > newBufferCap) {
            limit.bufferStored = newBufferCap;
        }

        emit BufferCapUpdate(oldBufferCap, newBufferCap);
    }
}

// node_modules/@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol

interface IMailbox {
    // ============ Events ============
    /**
     * @notice Emitted when a new message is dispatched via Hyperlane
     * @param sender The address that dispatched the message
     * @param destination The destination domain of the message
     * @param recipient The message recipient address on `destination`
     * @param message Raw bytes of message
     */
    event Dispatch(address indexed sender, uint32 indexed destination, bytes32 indexed recipient, bytes message);

    /**
     * @notice Emitted when a new message is dispatched via Hyperlane
     * @param messageId The unique message identifier
     */
    event DispatchId(bytes32 indexed messageId);

    /**
     * @notice Emitted when a Hyperlane message is processed
     * @param messageId The unique message identifier
     */
    event ProcessId(bytes32 indexed messageId);

    /**
     * @notice Emitted when a Hyperlane message is delivered
     * @param origin The origin domain of the message
     * @param sender The message sender address on `origin`
     * @param recipient The address that handled the message
     */
    event Process(uint32 indexed origin, bytes32 indexed sender, address indexed recipient);

    function localDomain() external view returns (uint32);

    function delivered(bytes32 messageId) external view returns (bool);

    function defaultIsm() external view returns (IInterchainSecurityModule);

    function defaultHook() external view returns (IPostDispatchHook);

    function requiredHook() external view returns (IPostDispatchHook);

    function latestDispatchedId() external view returns (bytes32);

    function dispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes calldata messageBody)
        external
        payable
        returns (bytes32 messageId);

    function quoteDispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes calldata messageBody)
        external
        view
        returns (uint256 fee);

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata body,
        bytes calldata defaultHookMetadata
    ) external payable returns (bytes32 messageId);

    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata defaultHookMetadata
    ) external view returns (uint256 fee);

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata body,
        bytes calldata customHookMetadata,
        IPostDispatchHook customHook
    ) external payable returns (bytes32 messageId);

    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata customHookMetadata,
        IPostDispatchHook customHook
    ) external view returns (uint256 fee);

    function process(bytes calldata metadata, bytes calldata message) external payable;

    function recipientIsm(address recipient) external view returns (IInterchainSecurityModule module);
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {}

    function __Context_init_unchained() internal onlyInitializing {}

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// src/interfaces/bridge/ILeafEscrowTokenBridge.sol

interface ILeafEscrowTokenBridge is ITokenBridge {
    error InvalidCommand();
    error ZeroTokenId();

    /// @notice Returns the domain of the root chain
    function ROOT_DOMAIN() external returns (uint32);

    /// @notice Max gas limit for token bridging transactions with locking
    /// @dev Can set a different gas limit by using a custom hook
    function GAS_LIMIT_LOCK() external view returns (uint256);

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// Unwrapped tokens are added to the lock with tokenId on root
    /// @dev If not possible to add to the lock, unwrapped tokens are sent to the recipient on root
    /// @param _recipient The address of the recipient on the root chain
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _tokenId The token id of the lock to deposit tokens for on the root chain
    function sendTokenAndLock(address _recipient, uint256 _amount, uint256 _tokenId) external payable;
}

// src/libraries/rateLimits/RateLimitedMidpointLibrary.sol

/// @title library for putting a rate limit on how fast a contract
/// can perform an action e.g. Minting and Burning with a midpoint
/// @author Elliot Friedman
/// @dev Modified lightly from Zelt at commit 30b2ba0 to update the Solidity Compiler version used
/// Can refer to: (https://github.com/solidity-labs-io/zelt/blob/30b2ba0352422471c03b233d55feddfbdba198a3/src/lib/RateLimitedMidpointLibrary.sol)
library RateLimitedMidpointLibrary {
    using RateLimitMidpointCommonLibrary for RateLimitMidPoint;

    /// @notice event emitted when buffer gets eaten into
    event BufferUsed(uint256 amountUsed, uint256 bufferRemaining);

    /// @notice event emitted when buffer gets replenished
    event BufferReplenished(uint256 amountReplenished, uint256 bufferRemaining);

    /// @notice the method that enforces the rate limit.
    /// Decreases buffer by "amount".
    /// If buffer is <= amount, revert
    /// @param limit pointer to the rate limit object
    /// @param amount to decrease buffer by
    function depleteBuffer(RateLimitMidPoint storage limit, uint256 amount) internal {
        /// SLOAD 2x
        uint256 newBuffer = limit.buffer();

        require(amount <= newBuffer, 'RateLimited: rate limit hit');

        uint32 blockTimestamp = uint32(block.timestamp);
        uint112 newBufferStored = uint112(newBuffer - amount);

        /// gas optimization to only use a single SSTORE
        limit.lastBufferUsedTime = blockTimestamp;
        limit.bufferStored = newBufferStored;

        emit BufferUsed(amount, newBufferStored);
    }

    /// @notice function to replenish buffer
    /// @param amount to increase buffer by if under buffer cap
    /// @param limit pointer to the rate limit object
    function replenishBuffer(RateLimitMidPoint storage limit, uint256 amount) internal {
        /// SLOAD 2x
        uint256 buffer = limit.buffer();
        /// warm SLOAD
        uint256 _bufferCap = limit.bufferCap;
        uint256 newBuffer = buffer + amount;

        require(newBuffer <= _bufferCap, 'RateLimited: buffer cap overflow');

        uint32 blockTimestamp = uint32(block.timestamp);
        /// ensure that bufferStored cannot be gt buffer cap
        uint112 newBufferStored = uint112(newBuffer);

        /// gas optimization to only use a single SSTORE
        limit.lastBufferUsedTime = blockTimestamp;
        limit.bufferStored = newBufferStored;

        emit BufferReplenished(amount, newBufferStored);
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), 'Ownable: caller is not the owner');
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// src/xerc20/MintLimits.sol

/// @dev Modified lightly from Zelt at commit 30b2ba0, with the following changes:
/// - Updated the Solidity compiler version used;
/// - Refactored the `_rateLimits` mapping to be internal;
/// - Removed internal `_addLimits(...)` & `_removeLimits(...)` helpers.
/// Can refer to: (https://github.com/solidity-labs-io/zelt/blob/30b2ba0352422471c03b233d55feddfbdba198a3/src/impl/MintLimits.sol)
abstract contract MintLimits {
    using RateLimitMidpointCommonLibrary for RateLimitMidPoint;
    using RateLimitedMidpointLibrary for RateLimitMidPoint;

    /// @notice struct for initializing rate limit
    struct RateLimitMidPointInfo {
        /// @notice the buffer cap for this bridge
        uint112 bufferCap;
        /// @notice the rate limit per second for this bridge
        uint128 rateLimitPerSecond;
        /// @notice the bridge address
        address bridge;
    }

    /// @notice rate limit for each bridge contract
    mapping(address bridge => RateLimitMidPoint bridgeRateLimit) internal _rateLimits;

    /// @notice emitted when a rate limit is added or removed
    /// @param bridge the bridge address
    /// @param bufferCap the new buffer cap for this bridge
    /// @param rateLimitPerSecond the new rate limit per second for this bridge
    event ConfigurationChanged(address indexed bridge, uint112 bufferCap, uint128 rateLimitPerSecond);

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// -------------------- View Functions ------------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    /// @notice the amount of action used before hitting limit
    /// @dev replenishes at rateLimitPerSecond per second up to bufferCap
    function buffer(address from) public view returns (uint256) {
        return _rateLimits[from].buffer();
    }

    /// @notice the cap of the buffer for this address
    /// @param from address to get buffer cap for
    function bufferCap(address from) public view returns (uint256) {
        return _rateLimits[from].bufferCap;
    }

    /// @notice the amount the buffer replenishes towards the midpoint per second
    /// @param from address to get rate limit for
    function rateLimitPerSecond(address from) public view returns (uint256) {
        return _rateLimits[from].rateLimitPerSecond;
    }

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// -------------- Internal Helper Functions -------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    //// ----------- Depleting and Replenishing Buffer --------------

    /// @notice the method that enforces the rate limit.
    /// Decreases buffer by "amount".
    /// If buffer is <= amount, revert
    /// @param amount to decrease buffer by
    function _depleteBuffer(address from, uint256 amount) internal {
        require(amount != 0, 'MintLimits: deplete amount cannot be 0');
        _rateLimits[from].depleteBuffer(amount);
    }

    /// @notice function to replenish buffer
    /// @param from address to set rate limit for
    /// @param amount to increase buffer by if under buffer cap
    function _replenishBuffer(address from, uint256 amount) internal {
        require(amount != 0, 'MintLimits: replenish amount cannot be 0');
        _rateLimits[from].replenishBuffer(amount);
    }

    //// -------------- Modifying Existing Limits -------------------

    /// @notice function to set rate limit per second
    /// @dev updates the current buffer and last buffer used time first,
    /// then sets the new rate limit per second
    /// @param from address to set rate limit for
    /// @param newRateLimitPerSecond new rate limit per second
    function _setRateLimitPerSecond(address from, uint128 newRateLimitPerSecond) internal {
        require(newRateLimitPerSecond <= maxRateLimitPerSecond(), 'MintLimits: rateLimitPerSecond too high');
        require(_rateLimits[from].bufferCap != 0, 'MintLimits: non-existent rate limit');

        _rateLimits[from].setRateLimitPerSecond(newRateLimitPerSecond);

        emit ConfigurationChanged(from, _rateLimits[from].bufferCap, newRateLimitPerSecond);
    }

    /// @notice function to set buffer cap
    /// @dev updates the current buffer and last buffer used time first,
    /// then sets the new buffer cap
    /// @param from address to set the buffer cap for
    /// @param newBufferCap new buffer cap
    function _setBufferCap(address from, uint112 newBufferCap) internal {
        require(newBufferCap != 0, 'MintLimits: bufferCap cannot be 0');
        require(_rateLimits[from].bufferCap != 0, 'MintLimits: non-existent rate limit');
        require(newBufferCap > minBufferCap(), 'MintLimits: buffer cap below min');

        _rateLimits[from].setBufferCap(newBufferCap);

        emit ConfigurationChanged(from, newBufferCap, _rateLimits[from].rateLimitPerSecond);
    }

    //// -------------- Adding Limits -------------------

    /// @notice add an individual rate limit
    /// @param rateLimit cap on buffer size for this rate limited instance
    function _addLimit(RateLimitMidPointInfo memory rateLimit) internal {
        require(rateLimit.rateLimitPerSecond <= maxRateLimitPerSecond(), 'MintLimits: rateLimitPerSecond too high');
        require(rateLimit.bridge != address(0), 'MintLimits: invalid bridge address');
        require(_rateLimits[rateLimit.bridge].bufferCap == 0, 'MintLimits: rate limit already exists');
        require(rateLimit.bufferCap > minBufferCap(), 'MintLimits: buffer cap below min');

        _rateLimits[rateLimit.bridge] = RateLimitMidPoint({
            bufferCap: rateLimit.bufferCap,
            lastBufferUsedTime: uint32(block.timestamp),
            bufferStored: uint112(rateLimit.bufferCap / 2),
            midPoint: uint112(rateLimit.bufferCap / 2),
            rateLimitPerSecond: rateLimit.rateLimitPerSecond
        });

        emit ConfigurationChanged(rateLimit.bridge, rateLimit.bufferCap, rateLimit.rateLimitPerSecond);
    }

    //// -------------- Removing Limits -------------------

    /// @notice remove a bridge from the rate limit mapping, deleting all data
    /// @param bridge the bridge address to remove
    function _removeLimit(address bridge) internal {
        require(_rateLimits[bridge].bufferCap != 0, 'MintLimits: cannot remove non-existent rate limit');

        delete _rateLimits[bridge];

        emit ConfigurationChanged(bridge, 0, 0);
    }

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// ---------------------- Virtual Function --------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    /// @notice the maximum rate limit per second allowed in any bridge
    /// must be overridden by child contract
    function maxRateLimitPerSecond() public pure virtual returns (uint128);

    /// @notice the minimum buffer cap, non inclusive
    /// must be overridden by child contract
    function minBufferCap() public pure virtual returns (uint112);
}

// src/bridge/DomainRegistry.sol

/// @title Domain Registry
/// @notice Contains logic for managing registered domain from which messages can be sent to or received from
abstract contract DomainRegistry is IDomainRegistry, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Stores list of trusted domains
    EnumerableSet.UintSet internal _domains;

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IDomainRegistry
    function registerDomain(uint32 _domain) external onlyOwner {
        if (_domain == block.chainid) revert InvalidDomain();
        if (_domains.contains({value: _domain})) revert AlreadyRegistered();
        _domains.add({value: _domain});
        emit DomainRegistered({_domain: _domain});
    }

    /// @inheritdoc IDomainRegistry
    function deregisterDomain(uint32 _domain) external onlyOwner {
        if (!_domains.contains({value: _domain})) revert NotRegistered();
        _domains.remove({value: _domain});
        emit DomainDeregistered({_domain: _domain});
    }

    /// @inheritdoc IDomainRegistry
    function domains() external view returns (uint256[] memory) {
        return _domains.values();
    }

    /// @inheritdoc IDomainRegistry
    function contains(uint32 _domain) external view returns (bool) {
        return _domains.contains({value: _domain});
    }
}

// src/interfaces/xerc20/IXERC20.sol

interface IXERC20 {
    /// @notice Emits when a limit is set
    /// @param _bridge The address of the bridge we are setting the limit to
    /// @param _bufferCap The updated buffer cap for the bridge
    event BridgeLimitsSet(address indexed _bridge, uint256 _bufferCap);

    /// @notice The address of the lockbox contract
    function lockbox() external view returns (address);

    /// @notice Maps bridge address to bridge rate limits
    /// @param _bridge The bridge we are viewing the limits of
    /// @return _rateLimit The limits of the bridge
    function rateLimits(address _bridge) external view returns (RateLimitMidPoint memory _rateLimit);

    /// @notice Returns the max limit of a bridge
    /// @param _bridge The bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function mintingMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the max limit of a bridge
    /// @param _bridge the bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function burningMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the current limit of a bridge
    /// @param _bridge The bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function mintingCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the current limit of a bridge
    /// @param _bridge the bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function burningCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Mints tokens for a user
    /// @dev Can only be called by a bridge
    /// @param _user The address of the user who needs tokens minted
    /// @param _amount The amount of tokens being minted
    function mint(address _user, uint256 _amount) external;

    /// @notice Burns tokens for a user
    /// @dev Can only be called by a bridge
    /// @param _user The address of the user who needs tokens burned
    /// @param _amount The amount of tokens being burned
    function burn(address _user, uint256 _amount) external;

    /// @notice Conform to the xERC20 setLimits interface
    /// @dev Can only be called if the bridge already has a buffer cap
    /// @param _bridge The bridge we are setting the limits of
    /// @param _newBufferCap The new buffer cap, uint112 max for unlimited
    function setBufferCap(address _bridge, uint256 _newBufferCap) external;

    /// @notice Sets rate limit per second for a bridge
    /// @dev Can only be called if the bridge already has a buffer cap
    /// @param _bridge The bridge we are setting the limits of
    /// @param _newRateLimitPerSecond The new rate limit per second
    function setRateLimitPerSecond(address _bridge, uint128 _newRateLimitPerSecond) external;

    /// @notice Adds a new bridge to the currently active bridges
    /// @param _newBridge The bridge to add
    function addBridge(MintLimits.RateLimitMidPointInfo memory _newBridge) external;

    /// @notice Removes a bridge from the currently active bridges
    /// deleting its buffer stored, buffer cap, mid point and last
    /// buffer used time
    /// @param _bridge The bridge to remove
    function removeBridge(address _bridge) external;
}

// src/bridge/BaseTokenBridge.sol

/// @title Velodrome Superchain Base Token Bridge
/// @notice Base Token Bridge contract to be extended in Root & Leaf implementations
abstract contract BaseTokenBridge is ITokenBridge, IHLHandler, ISpecifiesInterchainSecurityModule_1, DomainRegistry {
    /// @inheritdoc ITokenBridge
    address public immutable xerc20;
    /// @inheritdoc ITokenBridge
    address public immutable mailbox;
    /// @inheritdoc ITokenBridge
    address public hook;
    /// @inheritdoc ITokenBridge
    IInterchainSecurityModule public securityModule;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism) DomainRegistry(_owner) {
        xerc20 = _xerc20;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule_1
    function interchainSecurityModule() external view returns (IInterchainSecurityModule) {
        return securityModule;
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule_1
    function setInterchainSecurityModule(address _ism) external onlyOwner {
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ITokenBridge
    function setHook(address _hook) external onlyOwner {
        hook = _hook;
        emit HookSet({_newHook: _hook});
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint32 _domain) external payable virtual;

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint32 _domain, address _refundAddress)
        external
        payable
        virtual;

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable virtual;

    function _generateGasMetadata(address _hook, uint256 _value, address _refundAddress, bytes memory _message)
        internal
        view
        virtual
        returns (bytes memory)
    {
        /// @dev If custom hook is set, it should be used to estimate gas
        uint256 gasLimit = GAS_LIMIT();
        return StandardHookMetadata.formatMetadata({
            _msgValue: _value,
            _gasLimit: gasLimit,
            _refundAddress: _refundAddress,
            _customMetadata: ''
        });
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure virtual returns (uint256) {
        return 200_000;
    }
}

// node_modules/@hyperlane-xyz/core/contracts/Mailbox.sol

// ============ Internal Imports ============

// ============ External Imports ============

contract Mailbox is IMailbox, Indexed, Versioned, OwnableUpgradeable {
    // ============ Libraries ============

    using Message for bytes;
    using TypeCasts for bytes32;
    using TypeCasts for address;

    // ============ Constants ============

    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // ============ Public Storage ============

    // A monotonically increasing nonce for outbound unique message IDs.
    uint32 public nonce;

    // The latest dispatched message ID used for auth in post-dispatch hooks.
    bytes32 public latestDispatchedId;

    // The default ISM, used if the recipient fails to specify one.
    IInterchainSecurityModule public defaultIsm;

    // The default post dispatch hook, used for post processing of opting-in dispatches.
    IPostDispatchHook public defaultHook;

    // The required post dispatch hook, used for post processing of ALL dispatches.
    IPostDispatchHook public requiredHook;

    // Mapping of message ID to delivery context that processed the message.
    struct Delivery {
        address processor;
        uint48 blockNumber;
    }

    mapping(bytes32 => Delivery) internal deliveries;

    // ============ Events ============

    /**
     * @notice Emitted when the default ISM is updated
     * @param module The new default ISM
     */
    event DefaultIsmSet(address indexed module);

    /**
     * @notice Emitted when the default hook is updated
     * @param hook The new default hook
     */
    event DefaultHookSet(address indexed hook);

    /**
     * @notice Emitted when the required hook is updated
     * @param hook The new required hook
     */
    event RequiredHookSet(address indexed hook);

    // ============ Constructor ============
    constructor(uint32 _localDomain) {
        localDomain = _localDomain;
    }

    // ============ Initializers ============
    function initialize(address _owner, address _defaultIsm, address _defaultHook, address _requiredHook)
        external
        initializer
    {
        __Ownable_init();
        setDefaultIsm(_defaultIsm);
        setDefaultHook(_defaultHook);
        setRequiredHook(_requiredHook);
        transferOwnership(_owner);
    }

    // ============ External Functions ============
    /**
     * @notice Dispatches a message to the destination domain & recipient
     * using the default hook and empty metadata.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as bytes32
     * @param _messageBody Raw bytes content of message body
     * @return The message ID inserted into the Mailbox's merkle tree
     */
    function dispatch(uint32 _destinationDomain, bytes32 _recipientAddress, bytes calldata _messageBody)
        external
        payable
        override
        returns (bytes32)
    {
        return dispatch(_destinationDomain, _recipientAddress, _messageBody, _messageBody[0:0], defaultHook);
    }

    /**
     * @notice Dispatches a message to the destination domain & recipient.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @param hookMetadata Metadata used by the post dispatch hook
     * @return The message ID inserted into the Mailbox's merkle tree
     */
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata hookMetadata
    ) external payable override returns (bytes32) {
        return dispatch(destinationDomain, recipientAddress, messageBody, hookMetadata, defaultHook);
    }

    /**
     * @notice Computes quote for dipatching a message to the destination domain & recipient
     * using the default hook and empty metadata.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @return fee The payment required to dispatch the message
     */
    function quoteDispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes calldata messageBody)
        external
        view
        returns (uint256 fee)
    {
        return quoteDispatch(destinationDomain, recipientAddress, messageBody, messageBody[0:0], defaultHook);
    }

    /**
     * @notice Computes quote for dispatching a message to the destination domain & recipient.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @param defaultHookMetadata Metadata used by the default post dispatch hook
     * @return fee The payment required to dispatch the message
     */
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata defaultHookMetadata
    ) external view returns (uint256 fee) {
        return quoteDispatch(destinationDomain, recipientAddress, messageBody, defaultHookMetadata, defaultHook);
    }

    /**
     * @notice Attempts to deliver `_message` to its recipient. Verifies
     * `_message` via the recipient's ISM using the provided `_metadata`.
     * @param _metadata Metadata used by the ISM to verify `_message`.
     * @param _message Formatted Hyperlane message (refer to Message.sol).
     */
    function process(bytes calldata _metadata, bytes calldata _message) external payable override {
        /// CHECKS ///

        // Check that the message was intended for this mailbox.
        require(_message.version() == VERSION, 'Mailbox: bad version');
        require(_message.destination() == localDomain, 'Mailbox: unexpected destination');

        // Check that the message hasn't already been delivered.
        bytes32 _id = _message.id();
        require(delivered(_id) == false, 'Mailbox: already delivered');

        // Get the recipient's ISM.
        address recipient = _message.recipientAddress();
        IInterchainSecurityModule ism = recipientIsm(recipient);

        /// EFFECTS ///

        deliveries[_id] = Delivery({processor: msg.sender, blockNumber: uint48(block.number)});
        emit Process(_message.origin(), _message.sender(), recipient);
        emit ProcessId(_id);

        /// INTERACTIONS ///

        // Verify the message via the interchain security module.
        require(ism.verify(_metadata, _message), 'Mailbox: ISM verification failed');

        // Deliver the message to the recipient.
        IMessageRecipient(recipient).handle{value: msg.value}(_message.origin(), _message.sender(), _message.body());
    }

    /**
     * @notice Returns the account that processed the message.
     * @param _id The message ID to check.
     * @return The account that processed the message.
     */
    function processor(bytes32 _id) external view returns (address) {
        return deliveries[_id].processor;
    }

    /**
     * @notice Returns the account that processed the message.
     * @param _id The message ID to check.
     * @return The number of the block that the message was processed at.
     */
    function processedAt(bytes32 _id) external view returns (uint48) {
        return deliveries[_id].blockNumber;
    }

    // ============ Public Functions ============

    /**
     * @notice Dispatches a message to the destination domain & recipient.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @param metadata Metadata used by the post dispatch hook
     * @param hook Custom hook to use instead of the default
     * @return The message ID inserted into the Mailbox's merkle tree
     */
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata metadata,
        IPostDispatchHook hook
    ) public payable virtual returns (bytes32) {
        if (address(hook) == address(0)) {
            hook = defaultHook;
        }

        /// CHECKS ///

        // Format the message into packed bytes.
        bytes memory message = _buildMessage(destinationDomain, recipientAddress, messageBody);
        bytes32 id = message.id();

        /// EFFECTS ///

        latestDispatchedId = id;
        nonce += 1;
        emit Dispatch(msg.sender, destinationDomain, recipientAddress, message);
        emit DispatchId(id);

        /// INTERACTIONS ///
        uint256 requiredValue = requiredHook.quoteDispatch(metadata, message);
        // if underpaying, defer to required hook's reverting behavior
        if (msg.value < requiredValue) {
            requiredValue = msg.value;
        }
        requiredHook.postDispatch{value: requiredValue}(metadata, message);
        hook.postDispatch{value: msg.value - requiredValue}(metadata, message);

        return id;
    }

    /**
     * @notice Computes quote for dispatching a message to the destination domain & recipient.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @param metadata Metadata used by the post dispatch hook
     * @param hook Custom hook to use instead of the default
     * @return fee The payment required to dispatch the message
     */
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata metadata,
        IPostDispatchHook hook
    ) public view returns (uint256 fee) {
        if (address(hook) == address(0)) {
            hook = defaultHook;
        }

        bytes memory message = _buildMessage(destinationDomain, recipientAddress, messageBody);
        return requiredHook.quoteDispatch(metadata, message) + hook.quoteDispatch(metadata, message);
    }

    /**
     * @notice Returns true if the message has been processed.
     * @param _id The message ID to check.
     * @return True if the message has been delivered.
     */
    function delivered(bytes32 _id) public view override returns (bool) {
        return deliveries[_id].blockNumber > 0;
    }

    /**
     * @notice Sets the default ISM for the Mailbox.
     * @param _module The new default ISM. Must be a contract.
     */
    function setDefaultIsm(address _module) public onlyOwner {
        require(Address.isContract(_module), 'Mailbox: default ISM not contract');
        defaultIsm = IInterchainSecurityModule(_module);
        emit DefaultIsmSet(_module);
    }

    /**
     * @notice Sets the default post dispatch hook for the Mailbox.
     * @param _hook The new default post dispatch hook. Must be a contract.
     */
    function setDefaultHook(address _hook) public onlyOwner {
        require(Address.isContract(_hook), 'Mailbox: default hook not contract');
        defaultHook = IPostDispatchHook(_hook);
        emit DefaultHookSet(_hook);
    }

    /**
     * @notice Sets the required post dispatch hook for the Mailbox.
     * @param _hook The new default post dispatch hook. Must be a contract.
     */
    function setRequiredHook(address _hook) public onlyOwner {
        require(Address.isContract(_hook), 'Mailbox: required hook not contract');
        requiredHook = IPostDispatchHook(_hook);
        emit RequiredHookSet(_hook);
    }

    /**
     * @notice Returns the ISM to use for the recipient, defaulting to the
     * default ISM if none is specified.
     * @param _recipient The message recipient whose ISM should be returned.
     * @return The ISM to use for `_recipient`.
     */
    function recipientIsm(address _recipient) public view returns (IInterchainSecurityModule) {
        // use low-level staticcall in case of revert or empty return data
        (bool success, bytes memory returnData) =
            _recipient.staticcall(abi.encodeCall(ISpecifiesInterchainSecurityModule_0.interchainSecurityModule, ()));
        // check if call was successful and returned data
        if (success && returnData.length != 0) {
            // check if returnData is a valid address
            address ism = abi.decode(returnData, (address));
            // check if the ISM is a contract
            if (ism != address(0)) {
                return IInterchainSecurityModule(ism);
            }
        }
        // Use the default if a valid one is not specified by the recipient.
        return defaultIsm;
    }

    // ============ Internal Functions ============
    function _buildMessage(uint32 destinationDomain, bytes32 recipientAddress, bytes calldata messageBody)
        internal
        view
        returns (bytes memory)
    {
        return Message.formatMessage(
            VERSION, nonce, localDomain, msg.sender.addressToBytes32(), destinationDomain, recipientAddress, messageBody
        );
    }
}

// src/bridge/LeafTokenBridge.sol

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██╗     ███████╗ █████╗ ███████╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗     ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗
██║     ██╔══╝  ██╔══██║██╔══╝     ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝
███████╗███████╗██║  ██║██║        ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Leaf Token Bridge
/// @notice General Purpose Leaf Token Bridge
contract LeafTokenBridge is BaseTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;
    using Commands for bytes;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism)
        BaseTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {}

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint32 _domain) external payable virtual override {
        bytes memory message = abi.encodePacked(_recipient, _amount);

        _send({
            _amount: _amount,
            _recipient: _recipient,
            _domain: _domain,
            _message: message,
            _refundAddress: msg.sender
        });
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint32 _domain, address _refundAddress)
        external
        payable
        virtual
        override
    {
        bytes memory message = abi.encodePacked(_recipient, _amount);

        _send({
            _amount: _amount,
            _recipient: _recipient,
            _domain: _domain,
            _message: message,
            _refundAddress: _refundAddress
        });
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable virtual override {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) {
            revert NotBridge();
        }
        if (!_domains.contains({value: _origin})) revert NotRegistered();

        (address recipient, uint256 amount) = _message.recipientAndAmount();

        IXERC20(xerc20).mint({_user: recipient, _amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }

    function _send(uint256 _amount, address _recipient, uint32 _domain, bytes memory _message, address _refundAddress)
        internal
    {
        if (_amount == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_refundAddress == address(0)) revert ZeroAddress();
        if (!_domains.contains({value: _domain})) revert NotRegistered();

        address _hook = hook;
        bytes memory metadata =
            _generateGasMetadata({_hook: _hook, _value: msg.value, _refundAddress: _refundAddress, _message: _message});

        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        Mailbox(mailbox).dispatch{value: msg.value}({
            destinationDomain: _domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            metadata: metadata,
            hook: IPostDispatchHook(_hook)
        });

        emit SentMessage({
            _destination: _domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(_message),
            _metadata: string(metadata)
        });
    }
}

// src/bridge/LeafEscrowTokenBridge.sol

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██╗     ███████╗ █████╗ ███████╗███████╗███████╗ ██████╗██████╗  ██████╗ ██╗    ██╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝██╔════╝██╔══██╗██╔═══██╗██║    ██║╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗  █████╗  ███████╗██║     ██████╔╝██║   ██║██║ █╗ ██║   ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗  
██║     ██╔══╝  ██╔══██║██╔══╝  ██╔══╝  ╚════██║██║     ██╔══██╗██║   ██║██║███╗██║   ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝  
███████╗███████╗██║  ██║██║     ███████╗███████║╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝   ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Leaf Escrow Token Bridge
/// @notice Leaf Token Bridge wrapper with escrow support
contract LeafEscrowTokenBridge is LeafTokenBridge, ILeafEscrowTokenBridge {
    /// @inheritdoc ILeafEscrowTokenBridge
    uint32 public constant ROOT_DOMAIN = 10;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism)
        LeafTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {}

    /// @inheritdoc ILeafEscrowTokenBridge
    function sendTokenAndLock(address _recipient, uint256 _amount, uint256 _tokenId) external payable {
        if (_tokenId == 0) revert ZeroTokenId();
        bytes memory message = abi.encodePacked(_recipient, _amount, _tokenId);

        _send({
            _amount: _amount,
            _recipient: _recipient,
            _domain: ROOT_DOMAIN,
            _message: message,
            _refundAddress: msg.sender
        });
    }

    function _generateGasMetadata(address _hook, uint256 _value, address _refundAddress, bytes memory _message)
        internal
        view
        override
        returns (bytes memory)
    {
        uint256 gasLimit;
        uint256 length = _message.length;
        /// @dev If custom hook is set, it should be used to estimate gas
        if (length == Commands.SEND_TOKEN_LENGTH) {
            gasLimit = GAS_LIMIT();
        } else if (length == Commands.SEND_TOKEN_AND_LOCK_LENGTH) {
            gasLimit = GAS_LIMIT_LOCK();
        } else {
            revert InvalidCommand();
        }

        return StandardHookMetadata.formatMetadata({
            _msgValue: _value,
            _gasLimit: gasLimit,
            _refundAddress: _refundAddress,
            _customMetadata: ''
        });
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure override(BaseTokenBridge, ITokenBridge) returns (uint256) {
        return 190_000;
    }

    /// @inheritdoc ILeafEscrowTokenBridge
    function GAS_LIMIT_LOCK() public pure returns (uint256) {
        return 432_000;
    }
}
