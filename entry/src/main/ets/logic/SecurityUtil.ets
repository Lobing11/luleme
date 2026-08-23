/**
 * 鹿了么 - 加解密与生物识别工具
 *
 * PIN 使用 SHA-256（加盐）存储，不保存明文；
 * 生物识别使用系统 UserAuth Kit（指纹/人脸），需 ohos.permission.ACCESS_BIOMETRIC。
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { userAuth } from '@kit.UserAuthenticationKit';

/** 计算字符串的 SHA-256 十六进制摘要 */
export async function sha256Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA256');
  const textEncoder = new util.TextEncoder();
  const data: cryptoFramework.DataBlob = {
    data: textEncoder.encodeInto(input)
  };
  await md.update(data);
  const digest = await md.digest();
  let hex = '';
  for (let i = 0; i < digest.data.length; i++) {
    hex += digest.data[i].toString(16).padStart(2, '0');
  }
  return hex;
}

/** 生成随机盐 */
export function randomSalt(): string {
  return util.generateRandomUUID(true);
}

/** PIN 加盐哈希 */
export async function hashPin(pin: string, salt: string): Promise<string> {
  return await sha256Hex(`${salt}:${pin}`);
}

/** 校验 PIN 是否匹配存储的哈希 */
export async function verifyPin(pin: string, salt: string, storedHash: string): Promise<boolean> {
  const hash = await hashPin(pin, salt);
  return hash === storedHash;
}

/** 设备是否支持指纹或人脸（且已录入） */
export async function isBiometricAvailable(): Promise<boolean> {
  const st = await getBiometricStatus();
  return st.hardwareSupported && st.enrolled;
}

export interface BiometricStatus {
  /** 硬件是否支持指纹或人脸 */
  hardwareSupported: boolean;
  /** 是否已录入至少一种生物特征 */
  enrolled: boolean;
}

interface ErrorLike {
  code: number;
}

const CHECK_AVAILABLE: number = 0;
const CHECK_NOT_SUPPORTED: number = 1;
const CHECK_OTHER: number = 2;

async function checkBiometricType(authType: userAuth.UserAuthType): Promise<number> {
  try {
    await userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1);
    return CHECK_AVAILABLE;
  } catch (err) {
    const e = err as ErrorLike;
    // 12500005/12500006：硬件不支持或信任等级不足
    if (e.code === 12500005 || e.code === 12500006) {
      return CHECK_NOT_SUPPORTED;
    }
    // 12500010（未录入）、201（权限）等：界面仍可用，认证时再给引导
    return CHECK_OTHER;
  }
}

/** 区分「硬件不支持」与「未录入生物特征」 */
export async function getBiometricStatus(): Promise<BiometricStatus> {
  const fp = await checkBiometricType(userAuth.UserAuthType.FINGERPRINT);
  if (fp === CHECK_AVAILABLE) {
    return { hardwareSupported: true, enrolled: true };
  }
  const face = await checkBiometricType(userAuth.UserAuthType.FACE);
  if (face === CHECK_AVAILABLE) {
    return { hardwareSupported: true, enrolled: true };
  }
  const hardwareSupported = fp !== CHECK_NOT_SUPPORTED || face !== CHECK_NOT_SUPPORTED;
  return { hardwareSupported: hardwareSupported, enrolled: false };
}

/** 发起生物识别认证，返回是否通过 */
export async function startBiometricAuth(title: string): Promise<boolean> {
  const authParam: userAuth.AuthParam = {
    challenge: new Uint8Array([49, 50, 51, 52, 53]),
    authType: [
      userAuth.UserAuthType.FINGERPRINT,
      userAuth.UserAuthType.FACE
    ],
    authTrustLevel: userAuth.AuthTrustLevel.ATL1
  };
  const widgetParam: userAuth.WidgetParam = {
    title: title
  };
  try {
    const instance = await userAuth.getUserAuthInstance(authParam, widgetParam);
    const success: boolean = await new Promise<boolean>((resolve) => {
      instance.on('result', {
        onResult: (result: userAuth.UserAuthResult) => {
          resolve(result.result === userAuth.UserAuthResultCode.SUCCESS);
        }
      });
      instance.start();
    });
    return success;
  } catch (err) {
    return false;
  }
}
