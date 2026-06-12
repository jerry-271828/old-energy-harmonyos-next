// 聚光灯搜索：全局课程/目录搜索 + 拼音/首字母匹配。
// NavDestination 推栈页，从首页搜索入口进入。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { Nav } from '../utils/Nav';
import { PinyinSearch } from '../utils/PinyinSearch';
import { GlassCard, EmptyView } from '../components/glass/GlassKit';
import { UserApi } from '../net/api/UserApi';
import { StudyApi } from '../net/api/StudyApi';
import { TeacherEntity } from '../models/User';
import { CatalogNode } from '../models/Catalog';
import { CourseListItem } from '../models/Course';

const DOMAIN = 0x0002;
const TAG = 'SearchSpotlight';

interface SearchResult {
  type: string;    // 'catalog' | 'course'
  id: number;
  name: string;
  path: string;
  teacherName: string;
}

function flattenCatalogSearch(nodes: CatalogNode[], parentPath: string,
  teacherName: string): SearchResult[] {
  const results: SearchResult[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    const path = parentPath.length > 0 ? `${parentPath} / ${n.catalogName}` : n.catalogName;
    results.push({
      type: 'catalog',
      id: n.id,
      name: n.catalogName,
      path: path,
      teacherName: teacherName
    });
    if (n.childList !== null && n.childList.length > 0) {
      const sub = flattenCatalogSearch(n.childList, path, teacherName);
      for (let j = 0; j < sub.length; j++) {
        results.push(sub[j]);
      }
    }
  }
  return results;
}

@ComponentV2
export struct SearchSpotlight {
  ui: UiStore = UiStore.instance;

  @Local private query: string = '';
  @Local private allItems: SearchResult[] = [];
  @Local private filtered: SearchResult[] = [];
  @Local private loading: boolean = true;

  aboutToAppear(): void {
    this.buildIndex();
  }

  private async buildIndex(): Promise<void> {
    this.loading = true;
    try {
      const teachers = await UserApi.teachers();
      const all: SearchResult[] = [];
      for (let i = 0; i < teachers.length; i++) {
        const t = teachers[i];
        try {
          const tree = await StudyApi.course.catalogTree(t.teacherUserId);
          const flat = flattenCatalogSearch(tree, '', t.userName);
          for (let j = 0; j < flat.length; j++) {
            all.push(flat[j]);
          }
        } catch (e) {
          // skip failed teacher
        }
      }
      this.allItems = all;
      hilog.info(DOMAIN, TAG, 'search index built: %{public}d items', all.length);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'buildIndex failed: %{public}s', err.message);
    } finally {
      this.loading = false;
    }
  }

  @Monitor('query')
  onQueryChange(): void {
    this.doFilter();
  }

  private doFilter(): void {
    const q = this.query.trim();
    if (q.length === 0) {
      this.filtered = [];
      return;
    }
    const results: SearchResult[] = [];
    for (let i = 0; i < this.allItems.length; i++) {
      if (PinyinSearch.matches(this.allItems[i].name, q) ||
        PinyinSearch.matches(this.allItems[i].path, q)) {
        results.push(this.allItems[i]);
        if (results.length >= 50) {
          break;
        }
      }
    }
    this.filtered = results;
  }

  build() {
    NavDestination() {
      Column({ space: 0 }) {
        // Search header
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([Theme.TEXT])
            .onClick(() => {
              Nav.pop();
            })

          TextInput({ placeholder: '搜索课程、目录...', text: this.query })
            .layoutWeight(1)
            .height(42)
            .borderRadius(Theme.R_XL)
            .backgroundColor('#F0F2F5')
            .fontSize(Theme.F_BODY)
            .onChange((v: string) => {
              this.query = v;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: this.ui.topSafeVp + 8, bottom: 8 })

        if (this.loading) {
          Column({ space: 10 }) {
            LoadingProgress().width(36).height(36).color(Theme.PRIMARY)
            Text('正在建立搜索索引...')
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT_2)
          }
          .width('100%')
          .padding(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.query.trim().length === 0) {
          EmptyView({ text: '输入关键词或拼音首字母搜索' })
        } else if (this.filtered.length === 0) {
          EmptyView({ text: '未找到匹配结果' })
        } else {
          List({ space: 6 }) {
            ForEach(this.filtered, (item: SearchResult) => {
              ListItem() {
                GlassCard({ innerPadding: 12 }) {
                  Row({ space: 10 }) {
                    SymbolGlyph(item.type === 'catalog'
                      ? $r('sys.symbol.folder') : $r('sys.symbol.doc_richtext'))
                      .fontSize(20)
                      .fontColor([Theme.PRIMARY])

                    Column({ space: 3 }) {
                      Text(item.name)
                        .fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.TEXT)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${item.teacherName} / ${item.path}`)
                        .fontSize(Theme.F_MINI)
                        .fontColor(Theme.TEXT_3)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .width('100%')
              }
            }, (item: SearchResult) => `sr_${item.type}_${item.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 12, right: 12, bottom: 40 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG_CREAM)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      Nav.pop();
      return true;
    })
  }
}
