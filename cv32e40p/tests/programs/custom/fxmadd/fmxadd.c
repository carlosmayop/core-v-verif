#include <stdio.h>
#include <stdint.h>

typedef int32_t i32;
typedef uint32_t u32;
typedef int8_t i8;
typedef uint8_t u8;

#define MSTATUS_FS_INITIAL 0x00002000

void fp_enable ()
{
  unsigned int fs = MSTATUS_FS_INITIAL;

  asm volatile("csrs mstatus, %0;"
               "csrwi fcsr, 0;"
               "csrs mstatus, %0;"
               : : "r"(fs)
              );
}
// https://en.wikipedia.org/wiki/Xorshift
u32 xorshift32(u32 seed) {
    u32 x = seed;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	return x;
}

// FXMADD
int fxmadd(i32 a, i32 b, i32 c, u8 inm){
    uint64_t mult = a * b;
    uint64_t mult_shifted = mult >> inm;
    return mult_shifted + c;
}
__attribute__((always_inline))
inline i32 __fxmadd(i32 a, i32 b, i32 c, u8 inm) {
    int x;
    const u8 inm_low_bits = inm & 0b111 ;
    const u8 inm_high_bits = (inm >> 3) & 0b11;
    asm volatile(
        ".insn r4 CUSTOM_1, %4, %5, %0, %1, %2, %3\n"
        : "=r" (x)
        : "r" (a), "r" (b), "r" (c), "i" (inm_low_bits), "i" (inm_high_bits)
    );
    return x;
}
__attribute__((always_inline))
inline u8 test_fxmadd(const u8 inm, const u32 ntimes) {
    i32 a = 1, b = 2, c = 3;
    printf("Testing fxmac %u times\n", ntimes);
    for (int i = 0; i < ntimes; i++) {
        a = xorshift32(a);
        b = xorshift32(b);
        c = xorshift32(c);
        if (__fxmadd(a, b, c, inm) != fxmadd(a, b, c, inm)) {
            return 0;
        }
    }
    return 1;
}

__attribute__((always_inline))
inline i32 __genum(u8 S) {
    i32 r;
    const u8 sgen = (31 - S) & 0b11111;
    const u8 ilow = sgen & 0b111 ;
	const u8 ihigh = (sgen >> 3) & 0b11;
 
    asm volatile(
		".insn r4 CUSTOM_0, %[ilow], %[ihigh], %[r], x0, x0, x0\n"
        : [r] "=r" (r)
        : [ilow] "i" (ilow), [ihigh] "i" (ihigh)
        :
    );
    return r;
}

__attribute__((always_inline))
inline void __seed(u32 v) {
    asm volatile(
        ".insn r CUSTOM_0, 0, 0b1000000, x0, %[v], x0\n"
        :
        : [v] "r" (v)
        :
    );
}

__attribute__((always_inline))
inline void test_fxgen(u32 new_seed, u32 nsamples, u8 fxbits) {
    printf("Generating %u %u fxbit samples with seed %u\n", nsamples, fxbits, new_seed);
    __seed(new_seed);
    for (u32 i = 0; i < nsamples; i++) {
        uint32_t sample_fxp = __genum(fxbits);
        float sample_float = (float) sample_fxp / (1 << fxbits);
        printf("FP %f FXP %lu\n", sample_float, sample_fxp);
    }
}

int main() {
    //fp_enable();

    test_fxgen(0xBEBACAFE, 100, 10);
    if(test_fxmadd(10, 1000)) {
        printf("Test passed\n");
    }
}