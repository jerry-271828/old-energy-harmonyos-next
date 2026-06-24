// Pure-ArkTS DES/ECB/PKCS7 — byte-identical with CryptoJS DES.
// Ported from CryptoJS tripledes.js (word-level implementation).

// Permuted Choice 1 constants
const PC1: number[] = [
  57, 49, 41, 33, 25, 17, 9,  1,
  58, 50, 42, 34, 26, 18, 10, 2,
  59, 51, 43, 35, 27, 19, 11, 3,
  60, 52, 44, 36, 63, 55, 47, 39,
  31, 23, 15, 7,  62, 54, 46, 38,
  30, 22, 14, 6,  61, 53, 45, 37,
  29, 21, 13, 5,  28, 20, 12, 4
];

// Permuted Choice 2 constants
const PC2: number[] = [
  14, 17, 11, 24, 1,  5,
  3,  28, 15, 6,  21, 10,
  23, 19, 12, 4,  26, 8,
  16, 7,  27, 20, 13, 2,
  41, 52, 31, 37, 47, 55,
  30, 40, 51, 45, 33, 48,
  44, 49, 39, 56, 34, 53,
  46, 42, 50, 36, 29, 32
];

// Cumulative bit shift constants
const BIT_SHIFTS: number[] = [1, 2, 4, 6, 8, 10, 12, 14, 15, 17, 19, 21, 23, 25, 27, 28];

// Combined S-box + P permutation tables, flattened to 64-entry arrays.
// Each SBOX_P[i][idx] is looked up by extracting 6 bits from (rBlock ^ subKey[i]) & SBOX_MASK[i].
const SBOX_P0: number[] = [
  0x808200, 0x8000, 0x0, 0x808202, 0x8000, 0x2, 0x808202, 0x808000,
  0x808002, 0x808200, 0x8202, 0x800000, 0x2, 0x800000, 0x8000, 0x200,
  0x200, 0x808002, 0x808200, 0x8000, 0x808202, 0x8200, 0x200, 0x800002,
  0x800202, 0x200, 0x808002, 0x2, 0x800000, 0x800202, 0x2, 0x8202,
  0x202, 0x808202, 0x800200, 0x8002, 0x800200, 0x808000, 0x8200, 0x800202,
  0x8200, 0x800002, 0x808000, 0x202, 0x808000, 0x8202, 0x800202, 0x808200,
  0x8002, 0x202, 0x800002, 0x800200, 0x800002, 0x800200, 0x8002, 0x0,
  0x0, 0x8002, 0x202, 0x8200, 0x8202, 0x0, 0x800000, 0x808002
];
const SBOX_P1: number[] = [
  0x40084010, 0x40004000, 0x4000, 0x84010, 0x80000, 0x10, 0x40080010, 0x40004010,
  0x40000010, 0x40084010, 0x40084000, 0x40000000, 0x40004000, 0x80000, 0x10, 0x40080010,
  0x84000, 0x80010, 0x40004010, 0x0, 0x40000000, 0x4000, 0x84010, 0x40080000,
  0x80010, 0x40000010, 0x0, 0x84000, 0x4010, 0x40084000, 0x40080000, 0x4010,
  0x0, 0x84010, 0x40080010, 0x80000, 0x40004010, 0x40080000, 0x40084000, 0x4000,
  0x40080000, 0x40004000, 0x10, 0x40084010, 0x84010, 0x10, 0x4000, 0x40000000,
  0x4010, 0x40084000, 0x80000, 0x40000010, 0x80010, 0x40004010, 0x40000010, 0x80010,
  0x84000, 0x0, 0x40004000, 0x4010, 0x40000000, 0x40080010, 0x40084010, 0x84000
];
const SBOX_P2: number[] = [
  0x104, 0x4010100, 0x0, 0x4010004, 0x4000100, 0x0, 0x10104, 0x4000100,
  0x10004, 0x4000004, 0x4000004, 0x10000, 0x4010104, 0x10004, 0x4010000, 0x104,
  0x4000000, 0x4, 0x4010100, 0x100, 0x10100, 0x4010000, 0x4010004, 0x10104,
  0x4000104, 0x10100, 0x10000, 0x4000104, 0x4, 0x4010104, 0x100, 0x4000000,
  0x4010100, 0x4000000, 0x10004, 0x104, 0x10000, 0x4010100, 0x4000100, 0x0,
  0x100, 0x10004, 0x4010104, 0x4000100, 0x4000004, 0x100, 0x0, 0x4010004,
  0x4000104, 0x10000, 0x4000000, 0x4010104, 0x4, 0x10104, 0x10100, 0x4000004,
  0x4010000, 0x4000104, 0x104, 0x4010000, 0x10104, 0x4, 0x4010004, 0x10100
];
const SBOX_P3: number[] = [
  0x80401000, 0x80001040, 0x80001040, 0x40, 0x401040, 0x80400040, 0x80400000, 0x80001000,
  0x0, 0x401000, 0x401000, 0x80401040, 0x80000040, 0x0, 0x400040, 0x80400000,
  0x80000000, 0x1000, 0x400000, 0x80401000, 0x40, 0x400000, 0x80001000, 0x1040,
  0x80400040, 0x80000000, 0x1040, 0x400040, 0x1000, 0x401040, 0x80401040, 0x80000040,
  0x400040, 0x80400000, 0x401000, 0x80401040, 0x80000040, 0x0, 0x0, 0x401000,
  0x1040, 0x400040, 0x80400040, 0x80000000, 0x80401000, 0x80001040, 0x80001040, 0x40,
  0x80401040, 0x80000040, 0x80000000, 0x1000, 0x80400000, 0x80001000, 0x401040, 0x80400040,
  0x80001000, 0x1040, 0x400000, 0x80401000, 0x40, 0x400000, 0x1000, 0x401040
];
const SBOX_P4: number[] = [
  0x80, 0x1040080, 0x1040000, 0x21000080, 0x40000, 0x80, 0x20000000, 0x1040000,
  0x20040080, 0x40000, 0x1000080, 0x20040080, 0x21000080, 0x21040000, 0x40080, 0x20000000,
  0x1000000, 0x20040000, 0x20040000, 0x0, 0x20000080, 0x21040080, 0x21040080, 0x1000080,
  0x21040000, 0x20000080, 0x0, 0x21000000, 0x1040080, 0x1000000, 0x21000000, 0x40080,
  0x40000, 0x21000080, 0x80, 0x1000000, 0x20000000, 0x1040000, 0x21000080, 0x20040080,
  0x1000080, 0x20000000, 0x21040000, 0x1040080, 0x20040080, 0x80, 0x1000000, 0x21040000,
  0x21040080, 0x40080, 0x21000000, 0x21040080, 0x1040000, 0x0, 0x20040000, 0x21000000,
  0x40080, 0x1000080, 0x20000080, 0x40000, 0x0, 0x20040000, 0x1040080, 0x20000080
];
const SBOX_P5: number[] = [
  0x10000008, 0x10200000, 0x2000, 0x10202008, 0x10200000, 0x8, 0x10202008, 0x200000,
  0x10002000, 0x202008, 0x200000, 0x10000008, 0x200008, 0x10002000, 0x10000000, 0x2008,
  0x0, 0x200008, 0x10002008, 0x2000, 0x202000, 0x10002008, 0x8, 0x10200008,
  0x10200008, 0x0, 0x202008, 0x10202000, 0x2008, 0x202000, 0x10202000, 0x10000000,
  0x10002000, 0x8, 0x10200008, 0x202000, 0x10202008, 0x200000, 0x2008, 0x10000008,
  0x200000, 0x10002000, 0x10000000, 0x2008, 0x10000008, 0x10202008, 0x202000, 0x10200000,
  0x202008, 0x10202000, 0x0, 0x10200008, 0x8, 0x2000, 0x10200000, 0x202008,
  0x2000, 0x200008, 0x10002008, 0x0, 0x10202000, 0x10000000, 0x200008, 0x10002008
];
const SBOX_P6: number[] = [
  0x100000, 0x2100001, 0x2000401, 0x0, 0x400, 0x2000401, 0x100401, 0x2100400,
  0x2100401, 0x100000, 0x0, 0x2000001, 0x1, 0x2000000, 0x2100001, 0x401,
  0x2000400, 0x100401, 0x100001, 0x2000400, 0x2000001, 0x2100000, 0x2100400, 0x100001,
  0x2100000, 0x400, 0x401, 0x2100401, 0x100400, 0x1, 0x2000000, 0x100400,
  0x2000000, 0x100400, 0x100000, 0x2000401, 0x2000401, 0x2100001, 0x2100001, 0x1,
  0x100001, 0x2000000, 0x2000400, 0x100000, 0x2100400, 0x401, 0x100401, 0x2100400,
  0x401, 0x2000001, 0x2100401, 0x2100000, 0x100400, 0x0, 0x1, 0x2100401,
  0x0, 0x100401, 0x2100000, 0x400, 0x2000001, 0x2000400, 0x400, 0x100001
];
const SBOX_P7: number[] = [
  0x8000820, 0x20000, 0x8000000, 0x20, 0x20020, 0x8020820, 0x8020800, 0x800,
  0x8020000, 0x8000800, 0x20800, 0x8020020, 0x820, 0x0, 0x8000020, 0x20820,
  0x20820, 0x8020800, 0x20, 0x800, 0x8000800, 0x8000020, 0x8020020, 0x20000,
  0x0, 0x20020, 0x8020000, 0x8000820, 0x8020820, 0x20800, 0x820, 0x8000000,
  0x800, 0x8020820, 0x8000820, 0x8000000, 0x8020000, 0x20800, 0x20820, 0x20,
  0x8000020, 0x820, 0x20020, 0x8020800, 0x0, 0x8020020, 0x8000800, 0x20000,
  0x20000, 0x800, 0x8020020, 0x20820, 0x20, 0x8020000, 0x8000000, 0x8000820,
  0x8020820, 0x8000020, 0x8000800, 0x0, 0x20800, 0x820, 0x20020, 0x8020800
];

// Masks that select the 6-bit S-box input from the expanded half-block
const SBOX_MASK: number[] = [
  0xf8000001, 0x1f800000, 0x01f80000, 0x001f8000,
  0x0001f800, 0x00001f80, 0x000001f8, 0x8000001f
];

// Extract 6-bit index from a masked value for each S-box position.
// Each mask selects 6 scattered bits; this function packs them to 0-63.
function sboxIndex(i: number, v: number): number {
  // Force unsigned 32-bit
  v = v >>> 0;
  if (i === 0) {
    // Mask 0xf8000001: bits [31,30,29,28,27,0]
    return (((v >>> 27) & 0x1f) << 1) | (v & 1);
  }
  if (i === 7) {
    // Mask 0x8000001f: bits [31,4,3,2,1,0]
    return (((v >>> 31) & 1) << 5) | (v & 0x1f);
  }
  // Masks 1-6 are contiguous 6-bit fields:
  // i=1: bits 28-23 (shift 23), i=2: bits 24-19 (shift 19), ..., i=6: bits 8-3 (shift 3)
  const shift: number = 23 - (i - 1) * 4;
  return (v >>> shift) & 0x3f;
}

// Look up SBOX_P value for a given S-box and masked input
function sboxLookup(i: number, masked: number): number {
  const idx: number = sboxIndex(i, masked);
  if (i === 0) { return SBOX_P0[idx]; }
  if (i === 1) { return SBOX_P1[idx]; }
  if (i === 2) { return SBOX_P2[idx]; }
  if (i === 3) { return SBOX_P3[idx]; }
  if (i === 4) { return SBOX_P4[idx]; }
  if (i === 5) { return SBOX_P5[idx]; }
  if (i === 6) { return SBOX_P6[idx]; }
  return SBOX_P7[idx];
}

// Generate 16 subkeys from 2-word (64-bit) key, matching CryptoJS _doReset
function generateSubKeys(keyWords: number[]): number[][] {
  // Select 56 bits according to PC1
  const keyBits: number[] = [];
  for (let i = 0; i < 56; i++) {
    const keyBitPos: number = PC1[i] - 1;
    keyBits[i] = (keyWords[keyBitPos >>> 5] >>> (31 - keyBitPos % 32)) & 1;
  }

  // Assemble 16 subkeys
  const subKeys: number[][] = [];
  for (let nSubKey = 0; nSubKey < 16; nSubKey++) {
    const subKey: number[] = [0, 0, 0, 0, 0, 0, 0, 0];
    const bitShift: number = BIT_SHIFTS[nSubKey];

    for (let i = 0; i < 24; i++) {
      // Select from the left 28 key bits
      subKey[(i / 6) | 0] |= keyBits[((PC2[i] - 1) + bitShift) % 28] << (31 - i % 6);
      // Select from the right 28 key bits
      subKey[4 + ((i / 6) | 0)] |= keyBits[28 + (((PC2[i + 24] - 1) + bitShift) % 28)] << (31 - i % 6);
    }

    // Scale subkeys to match expanded 32-bit input positions
    subKey[0] = (subKey[0] << 1) | (subKey[0] >>> 31);
    for (let i = 1; i < 7; i++) {
      subKey[i] = subKey[i] >>> ((i - 1) * 4 + 3);
    }
    subKey[7] = (subKey[7] << 5) | (subKey[7] >>> 27);

    subKeys.push(subKey);
  }
  return subKeys;
}

// Encrypt one 64-bit block (two 32-bit words), matching CryptoJS _doCryptBlock
function doCryptBlock(lBlockIn: number, rBlockIn: number, subKeys: number[][]): number[] {
  let lBlock: number = lBlockIn;
  let rBlock: number = rBlockIn;
  let t: number = 0;

  // Initial permutation (IP) via bit swaps
  t = ((lBlock >>> 4) ^ rBlock) & 0x0f0f0f0f;
  rBlock ^= t;
  lBlock ^= t << 4;
  t = ((lBlock >>> 16) ^ rBlock) & 0x0000ffff;
  rBlock ^= t;
  lBlock ^= t << 16;
  t = ((rBlock >>> 2) ^ lBlock) & 0x33333333;
  lBlock ^= t;
  rBlock ^= t << 2;
  t = ((rBlock >>> 8) ^ lBlock) & 0x00ff00ff;
  lBlock ^= t;
  rBlock ^= t << 8;
  t = ((lBlock >>> 1) ^ rBlock) & 0x55555555;
  rBlock ^= t;
  lBlock ^= t << 1;

  // 16 Feistel rounds
  for (let round = 0; round < 16; round++) {
    const subKey: number[] = subKeys[round];
    const savedL: number = lBlock;
    const savedR: number = rBlock;

    let f: number = 0;
    for (let i = 0; i < 8; i++) {
      const masked: number = ((savedR ^ subKey[i]) & SBOX_MASK[i]) >>> 0;
      f |= sboxLookup(i, masked);
    }
    lBlock = savedR;
    rBlock = savedL ^ f;
  }

  // Undo swap from last round
  t = lBlock;
  lBlock = rBlock;
  rBlock = t;

  // Final permutation (FP) via bit swaps (inverse of IP)
  t = ((lBlock >>> 1) ^ rBlock) & 0x55555555;
  rBlock ^= t;
  lBlock ^= t << 1;
  t = ((rBlock >>> 8) ^ lBlock) & 0x00ff00ff;
  lBlock ^= t;
  rBlock ^= t << 8;
  t = ((rBlock >>> 2) ^ lBlock) & 0x33333333;
  lBlock ^= t;
  rBlock ^= t << 2;
  t = ((lBlock >>> 16) ^ rBlock) & 0x0000ffff;
  rBlock ^= t;
  lBlock ^= t << 16;
  t = ((lBlock >>> 4) ^ rBlock) & 0x0f0f0f0f;
  rBlock ^= t;
  lBlock ^= t << 4;

  return [lBlock >>> 0, rBlock >>> 0];
}

// Convert byte array to big-endian 32-bit word array
function bytesToWords(bytes: number[]): number[] {
  const words: number[] = [];
  for (let i = 0; i < bytes.length; i += 4) {
    words.push(
      ((bytes[i] & 0xff) << 24) |
      ((bytes[i + 1] & 0xff) << 16) |
      ((bytes[i + 2] & 0xff) << 8) |
      (bytes[i + 3] & 0xff)
    );
  }
  return words;
}

// Convert 32-bit word array to byte array
function wordsToBytes(words: number[]): number[] {
  const bytes: number[] = [];
  for (let i = 0; i < words.length; i++) {
    const w: number = words[i] >>> 0;
    bytes.push((w >>> 24) & 0xff);
    bytes.push((w >>> 16) & 0xff);
    bytes.push((w >>> 8) & 0xff);
    bytes.push(w & 0xff);
  }
  return bytes;
}

// PKCS7 pad to blockSize bytes
function pkcs7Pad(data: number[], blockSize: number): number[] {
  const padLen: number = blockSize - (data.length % blockSize);
  const padded: number[] = data.slice();
  for (let i = 0; i < padLen; i++) {
    padded.push(padLen);
  }
  return padded;
}

/**
 * DES/ECB/PKCS7 encryption, byte-identical with:
 *   CryptoJS.DES.encrypt(plaintext, keyWordArray, { mode: ECB, padding: PKCS7 })
 *
 * @param keyBytes  Key bytes (at least 8; only the first 8 are used)
 * @param plainBytes  Plaintext bytes
 * @returns Ciphertext bytes
 */
export function desEcbEncrypt(keyBytes: number[], plainBytes: number[]): number[] {
  const padded: number[] = pkcs7Pad(plainBytes, 8);
  const keyWords: number[] = bytesToWords(keyBytes.slice(0, 8));
  const subKeys: number[][] = generateSubKeys(keyWords);

  const out: number[] = [];
  for (let i = 0; i < padded.length; i += 8) {
    const blockWords: number[] = bytesToWords(padded.slice(i, i + 8));
    const result: number[] = doCryptBlock(blockWords[0], blockWords[1], subKeys);
    const resultBytes: number[] = wordsToBytes(result);
    for (let j = 0; j < resultBytes.length; j++) {
      out.push(resultBytes[j]);
    }
  }
  return out;
}
