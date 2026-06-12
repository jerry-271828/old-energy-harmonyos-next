import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'RawFile';

export class RawFile {
  static async read(ctx: common.UIAbilityContext, name: string): Promise<string> {
    try {
      const bytes: Uint8Array = await ctx.resourceManager.getRawFileContent(name);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeToString(bytes);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'read %{public}s failed: %{public}s', name, err.message);
      throw new Error(`RawFile.read failed for ${name}: ${err.message}`);
    }
  }
}
