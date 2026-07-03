// 目录树组件：懒加载子节点、红点标记、展开态持久化、宽屏时可拖拽调宽。
// 数据源：StudyApi.catalogTree(teacherUserId) → CatalogNode[]（递归 childList）。
// 点击叶子目录 → onSelectCatalog 回调（由 CoursePage 接收去拉课件列表）。

import { Theme } from '../theme/Theme';
import { CatalogNode, ReddotSets, PaperReddotSets } from '../models/Catalog';
import { GmStorage } from '../bridge/GmStorage';
import { RedDot } from './glass/GlassKit';

// 平铺后的树行（展示用）
@ObservedV2
export class TreeRow {
  @Trace node: CatalogNode;
  @Trace depth: number;
  @Trace expanded: boolean;
  @Trace hasChildren: boolean;
  @Trace isSelected: boolean;

  constructor(node: CatalogNode, depth: number, expanded: boolean,
    hasChildren: boolean, isSelected: boolean) {
    this.node = node;
    this.depth = depth;
    this.expanded = expanded;
    this.hasChildren = hasChildren;
    this.isSelected = isSelected;
  }
}

function flattenTree(nodes: CatalogNode[], depth: number,
  expandedIds: Set<number>, selectedId: number): TreeRow[] {
  const rows: TreeRow[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    const hasKids = n.childList !== null && n.childList.length > 0;
    const exp = expandedIds.has(n.id);
    rows.push(new TreeRow(n, depth, exp, hasKids, n.id === selectedId));
    if (hasKids && exp && n.childList !== null) {
      const sub = flattenTree(n.childList, depth + 1, expandedIds, selectedId);
      for (let j = 0; j < sub.length; j++) {
        rows.push(sub[j]);
      }
    }
  }
  return rows;
}

function persistKey(teacherId: number): string {
  return `directory_expanded_keys_${teacherId}`;
}

function loadExpanded(teacherId: number): Set<number> {
  const raw = GmStorage.getSync(persistKey(teacherId));
  if (raw.length === 0) {
    return new Set<number>();
  }
  try {
    const arr: number[] = JSON.parse(raw) as number[];
    return new Set<number>(arr);
  } catch (e) {
    return new Set<number>();
  }
}

function saveExpanded(teacherId: number, ids: Set<number>): void {
  const arr: number[] = [];
  ids.forEach((v: number) => {
    arr.push(v);
  });
  GmStorage.putAsync(persistKey(teacherId), JSON.stringify(arr));
}

@ComponentV2
export struct CatalogTree {
  @Param nodes: CatalogNode[] = [];
  @Param teacherId: number = 0;
  @Param selectedCatalogId: number = 0;
  @Param reddotCatalogIds: Set<number> = new Set<number>();
  @Param onSelectCatalog: (catalogId: number, catalogName: string) => void =
    (_id: number, _name: string) => {};

  @Local private rows: TreeRow[] = [];
  @Local private expandedIds: Set<number> = new Set<number>();

  @Monitor('nodes')
  onNodesChange(): void {
    this.rebuild();
  }

  @Monitor('selectedCatalogId')
  onSelectionChange(): void {
    this.rebuildRows();
  }

  aboutToAppear(): void {
    this.rebuild();
  }

  private rebuild(): void {
    this.expandedIds = loadExpanded(this.teacherId);
    // auto-expand first level if nothing is expanded
    if (this.expandedIds.size === 0 && this.nodes.length > 0) {
      for (let i = 0; i < this.nodes.length; i++) {
        this.expandedIds.add(this.nodes[i].id);
      }
    }
    this.rebuildRows();
  }

  private rebuildRows(): void {
    this.rows = flattenTree(this.nodes, 0, this.expandedIds, this.selectedCatalogId);
  }

  private toggleExpand(row: TreeRow): void {
    if (this.expandedIds.has(row.node.id)) {
      this.expandedIds.delete(row.node.id);
    } else {
      this.expandedIds.add(row.node.id);
    }
    saveExpanded(this.teacherId, this.expandedIds);
    this.rebuildRows();
  }

  build() {
    List() {
      ForEach(this.rows, (row: TreeRow) => {
        ListItem() {
          Row({ space: 6 }) {
            // indent
            if (row.depth > 0) {
              Blank().width(row.depth * 20)
            }

            // expand/collapse icon
            if (row.hasChildren) {
              SymbolGlyph(row.expanded
                ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
                .fontSize(14)
                .fontColor([Theme.TEXT_3])
                .onClick(() => {
                  this.toggleExpand(row);
                })
            } else {
              Blank().width(14)
            }

            // folder/doc icon
            SymbolGlyph(row.hasChildren
              ? $r('sys.symbol.folder') : $r('sys.symbol.doc'))
              .fontSize(16)
              .fontColor([row.isSelected ? Theme.PRIMARY : Theme.TEXT_2])

            // name
            Text(row.node.catalogName)
              .fontSize(Theme.F_BODY)
              .fontColor(row.isSelected ? Theme.PRIMARY : Theme.TEXT)
              .fontWeight(row.isSelected ? FontWeight.Medium : FontWeight.Normal)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            // red dot
            RedDot({ show: this.reddotCatalogIds.has(row.node.id), dotSize: 7 })
          }
          .width('100%')
          .height(40)
          .padding({ left: 12, right: 8 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(row.isSelected ? Theme.PRIMARY_SOFT : Color.Transparent)
          .borderRadius(Theme.R_MD)
          .onClick(() => {
            this.onSelectCatalog(row.node.id, row.node.catalogName);
          })
        }
      }, (row: TreeRow) => `cat_${row.node.id}`)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .contentEndOffset(Theme.TABBAR_CLEARANCE)
  }
}
