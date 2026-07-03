// 网页版回退入口（隐藏功能）：完整保留旧 WebView 壳 + 油猴注入链路。
// 入口在 设置 → 关于 → 「打开网页版（兼容模式）」。原生版未覆盖的长尾功能
// 可临时回到这里使用。实现与旧版 Index.ets 完全一致，仅外壳改为 NavDestination。

import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AndroidBridge } from '../bridge/AndroidBridge';
import { ScriptBuilder, InjectionBundle, UserScript } from '../utils/ScriptBuilder';
import { FloatPdfWindow, FloatState, FloatGeom, defaultFloatGeom } from './FloatPdfWindow';
import { ApiClient } from '../net/ApiClient';

interface PermResult {
  authResults: abilityAccessCtrl.GrantStatus[];
}

const DOMAIN = 0x0001;
const TAG = 'WebShellPage';

const ENTRY_URL: string = 'https://bdfz.xnykcxt.com:5002/stu/#/login';

// 沉浸式安全区兜底脚本（与旧版一致，见 viewport_fix.js 注释）
const SAFE_AREA_KICK: string =
  '(function(){try{var m=document.querySelector(\'meta[name="viewport"]\');' +
  'if(!m){m=document.createElement("meta");m.setAttribute("name","viewport");' +
  'm.setAttribute("content","width=device-width,initial-scale=1.0,viewport-fit=cover");' +
  '(document.head||document.documentElement).appendChild(m);}else{var c=m.getAttribute("content")||"";' +
  'if(c.indexOf("viewport-fit=cover")===-1){var n=/viewport-fit\\s*=/.test(c)?' +
  'c.replace(/viewport-fit\\s*=\\s*[^,;\\s]+/i,"viewport-fit=cover"):' +
  '(c.length?c+", viewport-fit=cover":"width=device-width,initial-scale=1.0,viewport-fit=cover");' +
  'm.setAttribute("content",n);}}' +
  'var id="__bxny_safe_area_css__";if(!document.getElementById(id)){var s=document.createElement("style");' +
  's.id=id;s.textContent="body{padding-top:env(safe-area-inset-top)!important;' +
  'padding-top:constant(safe-area-inset-top)!important;box-sizing:border-box!important;}";' +
  '(document.head||document.documentElement).appendChild(s);}}catch(e){}})();';

@Component
export struct WebShellPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: AndroidBridge = new AndroidBridge();
  @State private earlyScript: string = '';
  @State private userScripts: UserScript[] = [];
  @State private scriptReady: boolean = false;

  // 浮动 PDF 预览窗状态——同一时间至多一个。
  @State private floatUrl: string = '';
  @State private floatState: FloatState = 'closed';
  @State private floatGeom: FloatGeom = { x: 0, y: 0, w: 600, h: 800 };
  @State private floatSavedGeom: FloatGeom = { x: 0, y: 0, w: 600, h: 800 };
  @State private floatMount: boolean = false;
  @State private pageWidth: number = 1280;
  @State private pageHeight: number = 800;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ScriptBuilder.build(ctx).then((b: InjectionBundle) => {
      this.earlyScript = b.early;
      this.userScripts = b.scripts;
      this.scriptReady = true;
      hilog.info(DOMAIN, TAG, 'scripts ready: early=%{public}d, deferred-count=%{public}d',
        b.early.length, b.scripts.length);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'script build failed: %{public}s', err.message);
      this.scriptReady = true;
    });

    AndroidBridge.setFloatPdfOpener((url: string) => {
      this.openFloatPdf(url);
    });
  }

  aboutToDisappear(): void {
    AndroidBridge.setFloatPdfOpener(null);
  }

  private openFloatPdf(url: string): void {
    hilog.info(DOMAIN, TAG, 'openFloatPdf: %{public}s', url);

    // Sync the auth token as a cookie covering the full domain with path=/,
    // since the server-set login cookie (scoped to /stu/ at login time) may
    // not be sent to /exam/pdf/web/ requests that the float WebView makes.
    try {
      const token: string = ApiClient.getToken();
      if (token.length > 0) {
        const origin: string = ApiClient.ORIGIN;
        webview.WebCookieManager.configCookieSync(origin, 'token=' + token + '; path=/');
        hilog.info(DOMAIN, TAG, 'openFloatPdf: cookie synced for origin=%{public}s', origin);
      } else {
        hilog.warn(DOMAIN, TAG, 'openFloatPdf: no token available, cookie not synced');
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'openFloatPdf: cookie sync threw: %{public}s', err.message);
    }

    this.floatMount = false;
    setTimeout(() => {
      this.floatUrl = url;
      this.floatGeom = defaultFloatGeom(this.pageWidth, this.pageHeight);
      this.floatSavedGeom = this.floatGeom;
      this.floatState = 'normal';
      this.floatMount = true;
    }, 60);
  }

  private closeFloatPdf(): void {
    this.floatMount = false;
    this.floatUrl = '';
    this.floatState = 'closed';
  }

  private async ensureCameraPermission(ctx: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const status = atManager.checkAccessTokenSync(
        bundleInfo.appInfo.accessTokenId, 'ohos.permission.CAMERA');
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      const result = await (atManager.requestPermissionsFromUser(ctx, ['ohos.permission.CAMERA']) as Promise<PermResult>);
      return result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'cam perm check failed: %{public}s', err.message);
      return false;
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', err.message);
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.scriptReady) {
          Web({ src: ENTRY_URL, controller: this.controller })
            .domStorageAccess(true)
            .javaScriptAccess(true)
            .fileAccess(true)
            .imageAccess(true)
            .onlineImageAccess(true)
            .geolocationAccess(true)
            .zoomAccess(true)
            .overScrollMode(OverScrollMode.NEVER)
            .horizontalScrollBarAccess(false)
            .verticalScrollBarAccess(true)
            .mixedMode(MixedMode.All)
            .cacheMode(CacheMode.Default)
            .darkMode(WebDarkMode.Off)
            .databaseAccess(true)
            .mediaPlayGestureAccess(false)
            .layoutMode(WebLayoutMode.NONE)
            .javaScriptProxy({
              object: this.bridge,
              name: 'AndroidBridge',
              methodList: ['getValue', 'setValue', 'showNotification', 'xhrRequest', 'openFloatPdf'],
              controller: this.controller
            })
            .javaScriptOnDocumentStart([
              { script: this.earlyScript, scriptRules: ['*'] }
            ])
            .onControllerAttached(() => {
              try {
                webview.WebviewController.setWebDebuggingAccess(true);
              } catch (_) {
                // ignore
              }
              this.bridge.attach(this.controller);
            })
            .onPageBegin((event) => {
              const url = event?.url ?? '';
              hilog.info(DOMAIN, TAG, 'pageBegin: %{public}s', url);
              try {
                this.controller.runJavaScript(SAFE_AREA_KICK, (err, _result) => {
                  if (err) {
                    hilog.warn(DOMAIN, TAG, 'safe-area kick failed: %{public}s', err.message);
                  }
                });
              } catch (e) {
                const err = e as BusinessError;
                hilog.warn(DOMAIN, TAG, 'safe-area kick exception: %{public}s', err.message);
              }
            })
            .onPageEnd((event) => {
              const url = event?.url ?? '';
              hilog.info(DOMAIN, TAG, 'pageEnd: %{public}s', url);
              // 按 @match 过滤逐脚本注入（语义见 ScriptBuilder；不要外包 IIFE/guard）
              for (let i = 0; i < this.userScripts.length; i++) {
                const script = this.userScripts[i];
                if (!ScriptBuilder.matchesUrl(url, script.patterns)) {
                  continue;
                }
                const scriptName = script.name;
                try {
                  this.controller.runJavaScript(script.content, (err, _result) => {
                    if (err) {
                      hilog.error(DOMAIN, TAG, 'inject %{public}s failed: %{public}s',
                        scriptName, err.message);
                    }
                  });
                } catch (e) {
                  const err = e as BusinessError;
                  hilog.error(DOMAIN, TAG, 'inject %{public}s exception: %{public}s',
                    scriptName, err.message);
                }
              }
            })
            .onErrorReceive((event) => {
              const url = event?.request?.getRequestUrl() ?? '';
              const info = event?.error?.getErrorInfo() ?? '';
              hilog.warn(DOMAIN, TAG, 'errorReceive %{public}s: %{public}s', url, info);
            })
            .onConsole((event) => {
              const msg = event?.message;
              if (msg) {
                hilog.info(DOMAIN, TAG, '[web] %{public}s', msg.getMessage());
              }
              return false;
            })
            .onPermissionRequest((event) => {
              const req = event?.request;
              if (!req) {
                return;
              }
              const resources: string[] = req.getAccessibleResource();
              const wantsVideo: boolean = resources.indexOf('TYPE_VIDEO_CAPTURE') >= 0;
              const wantsAudio: boolean = resources.indexOf('TYPE_AUDIO_CAPTURE') >= 0;
              const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
              if (wantsVideo) {
                this.ensureCameraPermission(ctx).then((granted: boolean) => {
                  if (granted) {
                    req.grant(resources);
                  } else {
                    req.deny();
                    this.showToast('已拒绝相机权限');
                  }
                });
              } else if (wantsAudio) {
                req.deny();
              } else {
                req.grant(resources);
              }
            })
            .onDownloadStart((event) => {
              const url = event?.url ?? '';
              hilog.info(DOMAIN, TAG, 'downloadStart: %{public}s', url);
              this.showToast('开始下载: ' + url.substring(0, 80));
            })
            .onShowFileSelector(() => {
              return false;
            })
            .onLoadIntercept((event) => {
              const url = event?.data?.getRequestUrl() ?? '';
              if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:')) {
                return true;
              }
              return false;
            })
            .width('100%')
            .height('100%')
            .backgroundColor('#FFFFFF')
            .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD],
              [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
        } else {
          Column() {
            LoadingProgress().width(56).height(56).color('#5280FF')
            Text('正在加载注入脚本...').fontSize(14).fontColor('#888').margin({ top: 12 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#FFFFFF');
        }

        if (this.floatUrl.length > 0) {
          FloatPdfWindow({
            url: $floatUrl,
            state: $floatState,
            geom: $floatGeom,
            savedGeom: $floatSavedGeom,
            mounted: $floatMount,
            pageWidth: this.pageWidth,
            pageHeight: this.pageHeight,
            earlyScript: this.earlyScript,
            userScripts: this.userScripts,
            onCloseRequest: () => {
              this.closeFloatPdf();
            }
          })
        }

        if (this.floatUrl.length > 0 && this.floatState === 'minimized') {
          Row() {
            SymbolGlyph($r('sys.symbol.plus')).fontSize(26).fontColor([Color.White])
          }
          .width(56).height(56).borderRadius(28)
          .backgroundColor('#3367FF')
          .shadow({ radius: 12, color: '#66000000', offsetY: 4 })
          .justifyContent(FlexAlign.Center)
          .position({ x: this.pageWidth - 76, y: this.pageHeight - 96 })
          .onClick(() => {
            this.floatState = 'normal';
          })
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const w: number = newArea.width as number;
        const h: number = newArea.height as number;
        if (w > 0 && h > 0) {
          this.pageWidth = w;
          this.pageHeight = h;
        }
      })
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      // 先让网页历史回退；到底了才退出回退页
      try {
        if (this.controller.accessBackward()) {
          this.controller.backward();
          return true;
        }
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(DOMAIN, TAG, 'back failed: %{public}s', err.message);
      }
      return false;
    })
  }
}
