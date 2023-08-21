#! /usr/bin/env python3

# Implements the CIOS method of Montgomery multiplicaiton from Tolga Acar's
# thesis:
# https://www.microsoft.com/en-us/research/wp-content/uploads/1998/06/97Acar.pdf
# Also see https://hackmd.io/@gnark/modular_multiplication by the gnark team,
# but note that this file does't implement gnark's optimisations as the BN254
# scalar prime we use here doesn't qualify


import random

"""
Splits the high and low bits of val into two word_size-bit unsigned integers.
"""
def hilo(val, word_size):
    assert(val < 2 ** (2 * word_size))
    assert(val >= 0)
    hi = val >> 16;
    low = val & 65535;
    return hi, low


"""
Converts an integer into a list of word_size-bit words, of maximum num_words
length.
"""
def to_words_le(val, num_words, word_size):
    assert(val < 2 ** (num_words * word_size))
    assert(val >= 0)

    h = hex(val)[2:]
    while len(h) < word_size / 4 * num_words:
        h = "0" + h

    words = []
    for i in reversed(range(0, num_words)):
        s = i * 4
        e = i * 4 + 4
        words.append(int(h[s:e], 16))

    return words


"""
Convers a list of num_words words into an unsigned integer.
"""
def from_words_le(words, num_words, word_size):
    assert(len(words) == num_words)
    val = 0
    for i in (range(0, num_words)):
        assert(words[i] < 2 ** word_size)
        assert(words[i] >= 0)
        val += (2 ** ((num_words - i - 1) * word_size)) * words[num_words - 1 - i]

    return val


"""
Implements the Coarsely Integrated Operand Scanning (CIOS) Method of Montgomery
multiplicaiton.
"""
def cios_mon_pro(a, b, n, n0, num_words, word_size):
    a = to_words_le(a, num_words, word_size)
    b = to_words_le(b, num_words, word_size)
    n_orig = n
    n = to_words_le(n, num_words, word_size)

    t = [0] * (num_words + 2)

    for i in range(0, num_words):
        c = 0
        for j in range(0, num_words):
            c, t[j] = hilo(t[j] + a[j] * b[i] + c, word_size)

        t[num_words + 1], t[num_words] = hilo(t[num_words] + c, word_size)

        m = (t[0] * n0) % (2 ** word_size)
        c, _ = hilo(t[0] + m * n[0], word_size)

        for j in range(1, num_words):
          c, t[j - 1] = hilo(t[j] + m * n[j] + c, word_size)

        c, t[num_words - 1] = hilo(t[num_words] + c, word_size)
        t[num_words] = t[num_words + 1] + c

    t = t[0:num_words + 1]

    # Conditional subtraction
    # if t >= n
    t_lt_n = lt(t, n + [0], num_words + 1, word_size)
    t_int = from_words_le(t, num_words + 1, word_size)
    n_int = from_words_le(n, num_words, word_size)
    assert((t_int < n_int) == (t_lt_n))

    if not t_lt_n:
        t = sub(t, n + [0], num_words + 1, word_size)

    return from_words_le(t, num_words + 1, word_size)

    # t = from_words_le(t, num_words + 1, word_size)
    # if t >= n_orig:
        # return t - n_orig
    # else:
        # return t


"""
Implements Montgomery multiplicaiton but involves an expensive division
operation. Only used as a sanity check.
"""
def mon_pro(t, n, nprime, r):
    u = (t - ((t * nprime) % r) * n) // r
    if u >= n:
        return u - n
    return u


"""
Returns a < b where a and b are the integer representations of the
little-endian lists of words a_words and b_words.
"""
def lt(a_words, b_words, num_words, word_size):
    assert(len(a_words) == num_words);
    assert(len(b_words) == num_words);

    for idx in range(num_words):
        i = num_words - 1 - idx
        assert(a_words[i] < 2 ** word_size)
        assert(b_words[i] < 2 ** word_size)
        assert(a_words[i] >= 0)
        assert(b_words[i] >= 0)
        if a_words[i] < b_words[i]:
            return True
        elif a_words[i] > b_words[i]:
            return False
    return False


# Returns a - b. Assumes a >= b.
def sub(a_words, b_words, num_words, word_size):
    """
    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < 16u; i = i + 1u) {
        (*res).words[i] = (*a).words[i] - (*b).words[i] - borrow;
        if ((*a).words[i] < ((*b).words[i] + borrow)) {
            (*res).words[i] += 65536u;
            borrow = 1u;
        } else {
            borrow = 0u;
        }
    }
    return borrow;
    """

    a = a_words
    b = b_words
    w = 2 ** word_size
    borrow = 0
    res = [0] * num_words
    for i in range(0, num_words):
        res[i] = (a[i] - b[i] - borrow)
        if a[i] < (b[i] + borrow):
            res[i] = (res[i] + w)
            borrow = 1
        else:
            borrow = 0

    return res


def test_sub_and_lt():
    num_words = 16 # number of words per big integer
    word_size = 16 # word size in bits
    n = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    for _ in range(0, 100):
        a = random.randint(0, n)
        b = random.randint(0, n)
        if a < b:
            a, b = b, a
        c = a - b
        a_words = to_words_le(a, num_words, word_size)
        b_words = to_words_le(b, num_words, word_size)
        c_words = to_words_le(c, num_words, word_size)

        r = sub(a_words, b_words, num_words, word_size)
        assert(r == c_words)

        a_lt_b = lt(a_words, b_words, num_words, word_size)
        b_lt_a = lt(b_words, a_words, num_words, word_size)
        assert(a > b)
        assert(a_lt_b)
        assert(b_lt_a)


def main():
    # test_sub_and_lt()
    num_words = 16 # number of words per big integer
    word_size = 16 # word size in bits
    # rinv and nprime can be found using xgcd() in Sage
    # rinv = xgcd(r, n)[1]
    # nprime = xgcd(r, n)[2] % r
    r = 2 ** 256
    rinv = 9915499612839321149637521777990102151350674507940716049588462388200839649614
    n = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    nprime = 63337608412835713303214155666321450302732274313949655463074949594303195774977 % r
    neg_n_inv = r - nprime
    n0 = neg_n_inv % (2 ** word_size)

    assert((r * rinv - n * nprime) % n == 1)
    assert((r * rinv) % n == 1)
    assert((n * nprime) % r == 1)

    # Test from_words_le and to_words_le
    assert(from_words_le(to_words_le(n, num_words, word_size), num_words, word_size) == n)

    # a = 2
    # b = 3
    # a = 0x264c5c24daa38c2acbbb92651c4540d6cae0cce1515b889a401baa0e4687915c
    # b = 0x2f663889210ce842713e5cc30a485d50b07fff85fba23f7b7a8f43269ca6a5b8
    a = 1232482305169817524934279232579555412480089136724561689079192105165841933610
    b = 19900323050421962907828588969311003598760081093557609712199438976752488394175
    for _ in range(0, 1):
        # a = random.randint(0, n)
        # b = random.randint(0, n)
        ar = (a * r) % n
        br = (b * r) % n
        arbr = (ar * br) % n
        abr = mon_pro(arbr, n, nprime, r) % n

        print("ar: ", hex(ar))
        print("br: ", hex(br))
        print("ri: ", hex(rinv))
        print("abr:", hex(abr))

        assert(abr == a * b * r % n)
        assert(abr == arbr * rinv % n)
        assert(abr * rinv % n == a * b % n)

        # CIOS method
        cios_result = cios_mon_pro(ar, br, n, n0, num_words, word_size)
        assert(cios_result == abr % n)


if __name__ == "__main__":
    main()
