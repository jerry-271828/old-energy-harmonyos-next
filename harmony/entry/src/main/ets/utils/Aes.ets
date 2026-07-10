// AES-256/CBC/PKCS7 — byte-compatible with the web 前端（stu app.js）的 X-Custom-Auth 加密。
//
// 网页端（4.0.1）已把鉴权头从 DES/ECB 换成 AES：逆向自 app.<hash>.js 的 Y() 函数——
//   const key = CryptoJS.enc.Utf8.parse("348ebfa6d1f9708310cb8a7f88367bc5");  // 32 字节 → AES-256
//   const iv  = CryptoJS.lib.WordArray.random(16);                            // 随机 16 字节 IV
//   const ct  = CryptoJS.AES.encrypt(plain, key, { mode: CBC, padding: Pkcs7, iv });
//   return iv.toString(/*Hex*/) + ct.toString(/*Base64*/);                    // hex(iv) + base64(密文)
// 服务端按 前 32 个 hex 字符 = IV、其余 = base64 密文 拆分解密。
// （实测：抓 Playwright 登录请求头，用 Web Crypto 以本方案解出 {"domain":...,"version":"4.0.1","timestamp":<秒>}）
//
// 这里用系统 CryptoArchitectureKit 的同步接口实现，保持 buildAuthHeader() 为同步调用。

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0002;
const TAG = 'AesAuth';

// 标准 UTF-8 编码（鉴权明文全为 ASCII，无需处理代理对）。
function utf8Bytes(str: string): Uint8Array {
  const arr: number[] = [];
  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i);
    if (c < 0x80) {
      arr.push(c);
    } else if (c < 0x800) {
      arr.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F));
    } else {
      arr.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F));
    }
  }
  return Uint8Array.from(arr);
}

function bytesToHex(bytes: Uint8Array): string {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += ('0' + bytes[i].toString(16)).slice(-2);
  }
  return hex;
}

/**
 * AES/CBC/PKCS7 加密，输出 hex(随机IV) + base64(密文)，与 CryptoJS 版逐字节一致。
 *
 * @param keyStr    32 字符密钥串（其 UTF-8 字节直接作为 AES-256 密钥）
 * @param plainText 明文
 * @returns 拼接串；加密异常时返回 ''（与网页端 Y() 的 catch 行为一致）
 */
export function aesCbcEncrypt(keyStr: string, plainText: string): string {
  try {
    const keyBlob: cryptoFramework.DataBlob = { data: utf8Bytes(keyStr) };
    const symKey: cryptoFramework.SymKey =
      cryptoFramework.createSymKeyGenerator('AES256').convertKeySync(keyBlob);

    const ivBlob: cryptoFramework.DataBlob = cryptoFramework.createRandom().generateRandomSync(16);
    const ivSpec: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: ivBlob
    };

    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivSpec);
    const input: cryptoFramework.DataBlob = { data: utf8Bytes(plainText) };
    const out: cryptoFramework.DataBlob = cipher.doFinalSync(input);

    const ctB64 = new util.Base64Helper().encodeToStringSync(out.data, util.Type.BASIC);
    return bytesToHex(ivBlob.data) + ctB64;
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(DOMAIN, TAG, 'aes encrypt failed: %{public}s', err.message);
    return '';
  }
}
