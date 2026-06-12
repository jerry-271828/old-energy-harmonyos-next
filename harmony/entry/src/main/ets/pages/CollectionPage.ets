// 收藏页面：文件夹列表 → 收藏题目列表，支持标签管理。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { GlassCard, EmptyView, LoadingView, SquishButton } from '../components/glass/GlassKit';
import { HtmlRichText } from '../components/HtmlRichText';
import { CollectApi, CollectFolder, CollectItem, CollectTag } from '../net/api/CollectApi';

const DOMAIN = 0x0002;
const TAG = 'CollectionPage';

@ComponentV2
export struct CollectionPage {
  ui: UiStore = UiStore.instance;

  @Local private folders: CollectFolder[] = [];
  @Local private loadingFolders: boolean = true;
  @Local private selectedFolderId: number = 0;
  @Local private selectedFolderName: string = '';
  @Local private items: CollectItem[] = [];
  @Local private loadingItems: boolean = false;
  @Local private tags: CollectTag[] = [];
  @Local private showNewFolder: boolean = false;
  @Local private newFolderName: string = '';

  aboutToAppear(): void {
    this.loadFolders();
    this.loadTags();
  }

  private async loadFolders(): Promise<void> {
    this.loadingFolders = true;
    try {
      this.folders = await CollectApi.folders();
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadFolders failed: %{public}s', err.message);
    } finally {
      this.loadingFolders = false;
    }
  }

  private async loadTags(): Promise<void> {
    try {
      this.tags = await CollectApi.tags();
    } catch (e) {
      // non-critical
    }
  }

  private async selectFolder(folder: CollectFolder): Promise<void> {
    this.selectedFolderId = folder.id;
    this.selectedFolderName = folder.folderName;
    this.loadingItems = true;
    this.items = [];
    try {
      this.items = await CollectApi.items(folder.id, 1, 200);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadItems failed: %{public}s', err.message);
    } finally {
      this.loadingItems = false;
    }
  }

  private async createFolder(): Promise<void> {
    const name = this.newFolderName.trim();
    if (name.length === 0) {
      return;
    }
    try {
      const folder = await CollectApi.createFolder(name);
      this.folders.unshift(folder);
      this.folders = [...this.folders];
      this.newFolderName = '';
      this.showNewFolder = false;
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'createFolder failed: %{public}s', err.message);
    }
  }

  private async removeItem(item: CollectItem): Promise<void> {
    try {
      await CollectApi.removeItem(item.id);
      this.items = this.items.filter((i: CollectItem) => i.id !== item.id);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'removeItem failed: %{public}s', err.message);
    }
  }

  @Builder
  folderList() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('收藏夹')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.plus_circle'))
          .fontSize(22)
          .fontColor([Theme.PRIMARY])
          .onClick(() => {
            this.showNewFolder = !this.showNewFolder;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.showNewFolder) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '新收藏夹名称', text: this.newFolderName })
            .layoutWeight(1)
            .height(40)
            .borderRadius(Theme.R_LG)
            .backgroundColor('#F0F2F5')
            .fontSize(Theme.F_BODY)
            .onChange((v: string) => {
              this.newFolderName = v;
            })
            .onSubmit(() => {
              this.createFolder();
            })
          Button('创建')
            .fontSize(Theme.F_SUB)
            .height(40)
            .backgroundColor(Theme.PRIMARY)
            .onClick(() => {
              this.createFolder();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      if (this.loadingFolders) {
        LoadingView()
      } else if (this.folders.length === 0) {
        EmptyView({ text: '暂无收藏夹' })
      } else {
        List({ space: 8 }) {
          ForEach(this.folders, (folder: CollectFolder) => {
            ListItem() {
              GlassCard({ innerPadding: 14 }) {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.folder'))
                    .fontSize(22)
                    .fontColor([Theme.PRIMARY])
                  Column({ space: 3 }) {
                    Text(folder.folderName)
                      .fontSize(Theme.F_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                    Text(`${folder.collectCount} 题`)
                      .fontSize(Theme.F_MINI)
                      .fontColor(Theme.TEXT_3)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16)
                    .fontColor([Theme.TEXT_3])
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .onClick(() => {
                this.selectFolder(folder);
              })
            }
          }, (folder: CollectFolder) => `f_${folder.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 12, right: 12, bottom: 80 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  itemList() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(18)
          .fontColor([Theme.PRIMARY])
        Text(this.selectedFolderName)
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.selectedFolderId = 0;
        this.items = [];
      })

      Divider().color(Theme.DIVIDER)

      if (this.loadingItems) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.items.length === 0) {
        EmptyView({ text: '该收藏夹暂无题目' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: CollectItem) => {
            ListItem() {
              GlassCard({ innerPadding: 14 }) {
                Column({ space: 8 }) {
                  HtmlRichText({ html: item.questionStem })

                  if (item.answer !== null) {
                    Row({ space: 6 }) {
                      Text('答案')
                        .fontSize(Theme.F_SUB)
                        .fontColor(Theme.SUCCESS)
                      Text(item.answer)
                        .fontSize(Theme.F_SUB)
                        .fontColor(Theme.TEXT)
                        .layoutWeight(1)
                    }
                  }

                  if (item.questionAnalysis !== null && item.questionAnalysis.length > 0) {
                    HtmlRichText({ html: item.questionAnalysis, baseFontSize: Theme.F_SUB })
                  }

                  Row({ space: 8 }) {
                    if (item.courseName !== null) {
                      Text(item.courseName)
                        .fontSize(Theme.F_MINI)
                        .fontColor(Theme.TEXT_3)
                    }
                    Blank().layoutWeight(1)

                    if (item.tags !== null && item.tags.length > 0) {
                      ForEach(item.tags, (tag: string) => {
                        Text(tag)
                          .fontSize(Theme.F_MINI)
                          .fontColor(Theme.PRIMARY)
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .backgroundColor(Theme.PRIMARY_SOFT)
                          .borderRadius(Theme.R_SM)
                      }, (tag: string) => tag)
                    }

                    SymbolGlyph($r('sys.symbol.trash'))
                      .fontSize(16)
                      .fontColor([Theme.DANGER])
                      .onClick(() => {
                        this.removeItem(item);
                      })
                  }
                  .width('100%')
                }
                .width('100%')
              }
              .width('100%')
            }
          }, (item: CollectItem) => `ci_${item.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 12, right: 12, bottom: 80 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Column() {
      Text('我的收藏')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ top: this.ui.topSafeVp + 12, left: 20, right: 20, bottom: 8 })

      if (this.selectedFolderId > 0) {
        this.itemList()
      } else {
        this.folderList()
      }
    }
    .width('100%')
    .height('100%')
  }
}
