// 课程页（Tab 0）：教师列表 → 目录树 → 课件列表。
// 平板双栏：左侧教师Tabs+目录树 | 右侧课件列表。
// 手机单栏：教师横向滑动选择 + 目录树/课件列表切换。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { CatalogTree } from '../components/CatalogTree';
import { GlassCard, EmptyView, LoadingView, RedDot } from '../components/glass/GlassKit';
import { Nav } from '../utils/Nav';
import { TeacherEntity } from '../models/User';
import { CatalogNode, ReddotSets } from '../models/Catalog';
import { CourseListItem, CourseDetailParam } from '../models/Course';
import { UserApi } from '../net/api/UserApi';
import { StudyApi } from '../net/api/StudyApi';
import { ReddotApi } from '../net/api/ReddotApi';

const DOMAIN = 0x0002;
const TAG = 'CoursePage';

@ComponentV2
export struct CoursePage {
  ui: UiStore = UiStore.instance;

  @Local private teachers: TeacherEntity[] = [];
  @Local private selectedTeacherIdx: number = 0;
  @Local private catalogNodes: CatalogNode[] = [];
  @Local private selectedCatalogId: number = 0;
  @Local private selectedCatalogName: string = '';
  @Local private courseItems: CourseListItem[] = [];

  @Local private loadingTeachers: boolean = true;
  @Local private loadingCatalog: boolean = false;
  @Local private loadingCourses: boolean = false;
  @Local private reddotCatalogIds: Set<number> = new Set<number>();
  @Local private reddotCourseIds: Set<number> = new Set<number>();
  @Local private reddotTeacherIds: Set<number> = new Set<number>();

  aboutToAppear(): void {
    this.loadTeachers();
    this.loadReddots();
  }

  private async loadTeachers(): Promise<void> {
    this.loadingTeachers = true;
    try {
      this.teachers = await UserApi.teachers();
      hilog.info(DOMAIN, TAG, 'teachers loaded: %{public}d', this.teachers.length);
      if (this.teachers.length > 0) {
        this.selectTeacher(0);
      }
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'loadTeachers failed: %{public}s', err.message);
    } finally {
      this.loadingTeachers = false;
    }
  }

  private async loadReddots(): Promise<void> {
    try {
      const r: ReddotSets = await ReddotApi.courseSets();
      this.reddotCatalogIds = new Set<number>(r.catalogIds ?? []);
      this.reddotCourseIds = new Set<number>(r.courseIds ?? []);
      this.reddotTeacherIds = new Set<number>(r.teacherIds ?? []);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadReddots failed: %{public}s', err.message);
    }
  }

  private selectTeacher(idx: number): void {
    this.selectedTeacherIdx = idx;
    this.selectedCatalogId = 0;
    this.courseItems = [];
    this.loadCatalog();
  }

  private async loadCatalog(): Promise<void> {
    if (this.teachers.length === 0) {
      return;
    }
    const teacher = this.teachers[this.selectedTeacherIdx];
    this.loadingCatalog = true;
    this.catalogNodes = [];
    try {
      this.catalogNodes = await StudyApi.course.catalogTree(teacher.teacherUserId);
      hilog.info(DOMAIN, TAG, 'catalog loaded: %{public}d nodes for teacher %{public}d',
        this.catalogNodes.length, teacher.teacherUserId);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'loadCatalog failed: %{public}s', err.message);
    } finally {
      this.loadingCatalog = false;
    }
  }

  private async onSelectCatalog(catalogId: number, catalogName: string): Promise<void> {
    this.selectedCatalogId = catalogId;
    this.selectedCatalogName = catalogName;
    this.loadingCourses = true;
    this.courseItems = [];
    try {
      this.courseItems = await StudyApi.course.listByCatalog(catalogId);
      hilog.info(DOMAIN, TAG, 'courses loaded: %{public}d for catalog %{public}d',
        this.courseItems.length, catalogId);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'loadCourses failed: %{public}s', err.message);
    } finally {
      this.loadingCourses = false;
    }
  }

  private openCourseDetail(item: CourseListItem): void {
    const param: CourseDetailParam = { id: item.id, createTime: item.createTime };
    Nav.push('courseDetail', param);
  }

  @Builder
  teacherTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.teachers, (t: TeacherEntity, idx: number) => {
          Row({ space: 6 }) {
            Text(t.userName)
              .fontSize(Theme.F_BODY)
              .fontColor(this.selectedTeacherIdx === idx ? Color.White : Theme.TEXT)
              .fontWeight(this.selectedTeacherIdx === idx ? FontWeight.Medium : FontWeight.Normal)
            RedDot({ show: this.reddotTeacherIds.has(t.teacherUserId), dotSize: 6 })
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.selectedTeacherIdx === idx ? Theme.PRIMARY : Theme.SURFACE)
          .backgroundBlurStyle(this.selectedTeacherIdx === idx
            ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR)
          .borderRadius(Theme.R_XL)
          .border({ width: 1, color: this.selectedTeacherIdx === idx ? Theme.PRIMARY : '#20000000' })
          .onClick(() => {
            if (this.selectedTeacherIdx !== idx) {
              this.selectTeacher(idx);
            }
          })
        }, (t: TeacherEntity) => `t_${t.id}`)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(44)
  }

  @Builder
  courseList() {
    if (this.selectedCatalogId === 0) {
      EmptyView({ text: '请在左侧选择目录' })
    } else if (this.loadingCourses) {
      LoadingView()
    } else if (this.courseItems.length === 0) {
      EmptyView({ text: '该目录暂无课件' })
    } else {
      List({ space: 8 }) {
        ForEach(this.courseItems, (item: CourseListItem) => {
          ListItem() {
            Column() {
              GlassCard({ innerPadding: 14 }) {
                Row({ space: 10 }) {
                  SymbolGlyph($r('sys.symbol.doc_plaintext'))
                    .fontSize(20)
                    .fontColor([Theme.PRIMARY])

                  Column({ space: 4 }) {
                    Text(item.courseName)
                      .fontSize(Theme.F_BODY)
                      .fontColor(Theme.TEXT)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    if (item.coursePublishTime) {
                      Text(item.coursePublishTime)
                        .fontSize(Theme.F_MINI)
                        .fontColor(Theme.TEXT_3)
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Row() {
                    RedDot({
                      show: this.reddotCourseIds.has(item.originCourseId),
                      dotSize: 7
                    })
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([Theme.TEXT_3])
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
            }
            .width('100%')
            .onClick(() => {
              this.openCourseDetail(item);
            })
          }
        }, (item: CourseListItem) => `c_${item.id}`)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12, bottom: 80 })
    }
  }

  @Builder
  sidebarContent() {
    Column() {
      if (this.loadingCatalog) {
        LoadingView({ text: '加载目录...' })
      } else if (this.catalogNodes.length === 0) {
        EmptyView({ text: '暂无目录' })
      } else {
        CatalogTree({
          nodes: this.catalogNodes,
          teacherId: this.teachers.length > 0
            ? this.teachers[this.selectedTeacherIdx].teacherUserId : 0,
          selectedCatalogId: this.selectedCatalogId,
          reddotCatalogIds: this.reddotCatalogIds,
          onSelectCatalog: (id: number, name: string) => {
            this.onSelectCatalog(id, name);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  wideModeLayout() {
    Row() {
      // Left sidebar: teacher tabs + catalog tree
      Column({ space: 0 }) {
        this.teacherTabs()
        Divider().color(Theme.DIVIDER).width('100%')
        this.sidebarContent()
      }
      .width('35%')
      .constraintSize({ minWidth: 240, maxWidth: 400 })
      .height('100%')
      .backgroundColor(Theme.BG_CREAM_DEEP)

      Divider().vertical(true).color(Theme.DIVIDER).height('100%')

      // Right content: course list
      Column() {
        if (this.selectedCatalogName.length > 0) {
          Text(this.selectedCatalogName)
            .fontSize(Theme.F_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        this.courseList()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  narrowModeLayout() {
    Column() {
      this.teacherTabs()
      Divider().color(Theme.DIVIDER).width('100%')

      if (this.selectedCatalogId > 0) {
        // Show course list with back-to-tree button
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(18)
            .fontColor([Theme.PRIMARY])
          Text(this.selectedCatalogName)
            .fontSize(Theme.F_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.PRIMARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .onClick(() => {
          this.selectedCatalogId = 0;
          this.courseItems = [];
        })

        Divider().color(Theme.DIVIDER).width('100%')
        this.courseList()
      } else {
        this.sidebarContent()
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Text('课 程')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ top: this.ui.topSafeVp + 12, left: 20, right: 20, bottom: 8 })

      if (this.loadingTeachers) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.teachers.length === 0) {
        EmptyView({ text: '暂无教师，请先添加教师' })
          .layoutWeight(1)
      } else {
        if (this.ui.isWide) {
          this.wideModeLayout()
        } else {
          this.narrowModeLayout()
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
