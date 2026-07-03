// 收藏页面：对齐官方网页端 /collection?pageid=3。
// 结构：教师目录 + 类型/标签筛选 + 收藏内容列表。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { GlassCard, EmptyView, LoadingView, SquishButton } from '../components/glass/GlassKit';
import { HtmlRichText } from '../components/HtmlRichText';
import { Nav } from '../utils/Nav';
import { AttachmentEntity } from '../models/Course';
import { AttachmentViewerParam } from './AttachmentViewerPage';
import {
  CollectApi,
  CollectTeacherItem,
  CollectItem,
  CollectResource,
  CollectResourceContent,
  CollectTag,
  CollectTagRef,
  CollectConditionBody,
  CollectDeleteBody,
  CollectEntityBody
} from '../net/api/CollectApi';

const DOMAIN = 0x0002;
const TAG = 'CollectionPage';

interface CollectTypeFilter {
  id: number;
  name: string;
}

@ComponentV2
export struct CollectionPage {
  ui: UiStore = UiStore.instance;

  @Local private teachers: CollectTeacherItem[] = [];
  @Local private selectedIdx: number = -1;
  @Local private selectedTypes: number[] = [];
  @Local private allTags: CollectTag[] = [];
  @Local private selectedTagIds: number[] = [];
  @Local private items: CollectItem[] = [];

  @Local private loadingCatalog: boolean = true;
  @Local private loadingItems: boolean = false;
  @Local private errorText: string = '';
  @Local private hasSelectedTeacher: boolean = false;
  @Local private expandedKey: string = '';
  @Local private showTagPanel: boolean = false;
  @Local private editingKey: string = '';
  @Local private newTagText: string = '';
  @Local private removingKey: string = '';

  private typeFilters: CollectTypeFilter[] = [
    { id: 0, name: '文字' },
    { id: 1, name: '文件' },
    { id: 2, name: '题' }
  ];

  aboutToAppear(): void {
    this.loadCatalog();
    this.loadTags();
  }

  private async loadCatalog(): Promise<void> {
    this.loadingCatalog = true;
    this.errorText = '';
    try {
      this.teachers = await CollectApi.catalog();
      if (this.teachers.length > 0) {
        this.selectedIdx = -1;
        this.hasSelectedTeacher = false;
        this.items = [];
      } else {
        this.selectedIdx = -1;
        this.hasSelectedTeacher = false;
        this.items = [];
      }
      hilog.info(DOMAIN, TAG, 'collect catalog loaded: %{public}d', this.teachers.length);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || '收藏目录加载失败';
      hilog.error(DOMAIN, TAG, 'loadCatalog failed: %{public}s', this.errorText);
    } finally {
      this.loadingCatalog = false;
    }
  }

  private async loadTags(): Promise<void> {
    try {
      const rows = await CollectApi.tags();
      rows.forEach((tag: CollectTag) => {
        tag.check = this.containsNumber(this.selectedTagIds, tag.id);
      });
      this.allTags = rows;
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadTags failed: %{public}s', err.message);
    }
  }

  private currentTeacher(): CollectTeacherItem | null {
    if (this.selectedIdx < 0 || this.selectedIdx >= this.teachers.length) {
      return null;
    }
    let result: CollectTeacherItem | null = null;
    this.teachers.forEach((teacher: CollectTeacherItem, idx: number) => {
      if (idx === this.selectedIdx) {
        result = teacher;
      }
    });
    return result;
  }

  private currentTitle(): string {
    const t = this.currentTeacher();
    if (t === null) {
      return '收藏';
    }
    return `${t.userName} (${t.subjectName})`;
  }

  private async selectTeacher(idx: number): Promise<void> {
    if (this.selectedIdx === idx && this.errorText.length === 0) {
      return;
    }
    this.selectedIdx = idx;
    this.hasSelectedTeacher = true;
    this.expandedKey = '';
    this.editingKey = '';
    await this.loadItems();
  }

  private async loadItems(): Promise<void> {
    const teacher = this.currentTeacher();
    if (!this.hasSelectedTeacher || teacher === null) {
      this.items = [];
      return;
    }
    this.loadingItems = true;
    this.errorText = '';
    this.items = [];
    try {
      const body: CollectConditionBody = {
        subjectId: teacher.subjectId,
        teacherId: teacher.teacherUserId,
        contentType: this.selectedTypes,
        tagIds: this.selectedTagIds
      };
      this.items = await CollectApi.condition(body);
      hilog.info(DOMAIN, TAG, 'collect items loaded: %{public}d', this.items.length);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || '收藏内容加载失败';
      hilog.error(DOMAIN, TAG, 'loadItems failed: %{public}s', this.errorText);
    } finally {
      this.loadingItems = false;
    }
  }

  private async retryCurrent(): Promise<void> {
    if (this.teachers.length === 0 && !this.hasSelectedTeacher) {
      await this.loadCatalog();
      return;
    }
    await this.loadItems();
  }

  private async toggleType(id: number): Promise<void> {
    if (!this.hasSelectedTeacher || this.selectedIdx < 0) {
      this.showToast('请先选择一个目录');
      return;
    }
    if (this.containsNumber(this.selectedTypes, id)) {
      const next: number[] = [];
      this.selectedTypes.forEach((v: number) => {
        if (v !== id) {
          next.push(v);
        }
      });
      this.selectedTypes = next;
    } else {
      const next: number[] = [];
      this.selectedTypes.forEach((v: number) => {
        next.push(v);
      });
      next.push(id);
      this.selectedTypes = next;
    }
    await this.loadItems();
  }

  private toggleTagFilter(tag: CollectTag): void {
    const next: number[] = [];
    let found = false;
    this.selectedTagIds.forEach((id: number) => {
      if (id === tag.id) {
        found = true;
      } else {
        next.push(id);
      }
    });
    if (!found) {
      next.push(tag.id);
    }
    this.selectedTagIds = next;
    this.syncTagChecks();
  }

  private async applyTagFilter(): Promise<void> {
    if (!this.hasSelectedTeacher) {
      this.showToast('请先选择一个目录');
      return;
    }
    this.showTagPanel = false;
    await this.loadItems();
  }

  private async clearTagFilter(): Promise<void> {
    this.selectedTagIds = [];
    this.syncTagChecks();
    this.showTagPanel = false;
    if (this.hasSelectedTeacher) {
      await this.loadItems();
    }
  }

  private syncTagChecks(): void {
    const rows: CollectTag[] = [];
    this.allTags.forEach((tag: CollectTag) => {
      tag.check = this.containsNumber(this.selectedTagIds, tag.id);
      rows.push(tag);
    });
    this.allTags = rows;
  }

  private startEditTags(item: CollectItem): void {
    this.editingKey = this.itemKey(item);
    this.newTagText = '';
    const ids = this.itemTagIds(item);
    const rows: CollectTag[] = [];
    this.allTags.forEach((tag: CollectTag) => {
      tag.check = this.containsNumber(ids, tag.id);
      rows.push(tag);
    });
    this.allTags = rows;
  }

  private cancelEditTags(): void {
    this.editingKey = '';
    this.newTagText = '';
    this.syncTagChecks();
  }

  private toggleEditTag(tag: CollectTag): void {
    const rows: CollectTag[] = [];
    this.allTags.forEach((item: CollectTag) => {
      if (item.id === tag.id) {
        item.check = !(item.check === true);
      }
      rows.push(item);
    });
    this.allTags = rows;
  }

  private async saveTags(item: CollectItem): Promise<void> {
    const resource = item.content;
    let selectedRefs: CollectTagRef[] = [];
    this.allTags.forEach((tag: CollectTag) => {
      if (tag.check === true) {
        const ref: CollectTagRef = { id: tag.id };
        selectedRefs.push(ref);
      }
    });
    const names = this.parseNewTagNames(this.newTagText);
    if (names === null) {
      return;
    }
    if (selectedRefs.length + names.length > 2) {
      this.showToast('每个资源最多设置两个标签');
      return;
    }
    try {
      for (const name of names) {
        const created = await CollectApi.createTag(name);
        const ref: CollectTagRef = { id: created.id };
        const nextRefs: CollectTagRef[] = [ref];
        selectedRefs.forEach((item: CollectTagRef) => {
          nextRefs.push(item);
        });
        selectedRefs = nextRefs;
        const newTag: CollectTag = {
          id: created.id,
          tagName: created.tagName,
          check: false
        };
        if (created.studentId !== undefined) {
          newTag.studentId = created.studentId;
        }
        const nextTags: CollectTag[] = [newTag];
        this.allTags.forEach((tag: CollectTag) => {
          nextTags.push(tag);
        });
        this.allTags = nextTags;
      }
      const oldRefs = this.itemTagRefs(item);
      if (oldRefs.length > 0) {
        const delBody: CollectEntityBody = {
          sourceId: resource.sourceId,
          sourceType: resource.sourceType,
          courseId: resource.courseId,
          tagList: oldRefs,
          type: resource.type
        };
        await CollectApi.deleteTags(delBody);
      }
      if (selectedRefs.length > 0) {
        const saveBody: CollectEntityBody = {
          sourceId: resource.sourceId,
          sourceType: resource.sourceType,
          courseId: resource.courseId,
          tagList: selectedRefs,
          type: resource.type
        };
        await CollectApi.saveEntity(saveBody);
      }
      resource.tagList = this.tagsByRefs(selectedRefs);
      this.items = this.items.slice();
      this.cancelEditTags();
      this.showToast('标签修改成功');
    } catch (e) {
      const err = e as Error;
      this.showToast(err.message || '标签修改失败');
      hilog.error(DOMAIN, TAG, 'saveTags failed: %{public}s', err.message);
    }
  }

  private async removeItem(item: CollectItem): Promise<void> {
    const resource = item.content;
    const key = this.itemKey(item);
    this.removingKey = key;
    try {
      const body: CollectDeleteBody = {
        sourceId: resource.sourceId,
        sourceType: resource.sourceType,
        courseId: resource.courseId,
        type: resource.type
      };
      await CollectApi.remove(body);
      const nextItems: CollectItem[] = [];
      this.items.forEach((row: CollectItem) => {
        if (this.itemKey(row) !== key) {
          nextItems.push(row);
        }
      });
      this.items = nextItems;
      if (this.expandedKey === key) {
        this.expandedKey = '';
      }
      this.showToast('已删除收藏');
    } catch (e) {
      const err = e as Error;
      this.showToast(err.message || '删除失败');
      hilog.error(DOMAIN, TAG, 'removeItem failed: %{public}s', err.message);
    } finally {
      this.removingKey = '';
    }
  }

  private itemKey(item: CollectItem): string {
    const c = item.content;
    return `${c.type}_${c.sourceType}_${c.sourceId}_${c.courseId}`;
  }

  private containsNumber(rows: number[], value: number): boolean {
    for (const item of rows) {
      if (item === value) {
        return true;
      }
    }
    return false;
  }

  private itemTagIds(item: CollectItem): number[] {
    const ids: number[] = [];
    item.content.tagList.forEach((tag: CollectTag) => {
      ids.push(tag.id);
    });
    return ids;
  }

  private itemTagRefs(item: CollectItem): CollectTagRef[] {
    const refs: CollectTagRef[] = [];
    item.content.tagList.forEach((tag: CollectTag) => {
      const ref: CollectTagRef = { id: tag.id };
      refs.push(ref);
    });
    return refs;
  }

  private tagsByRefs(refs: CollectTagRef[]): CollectTag[] {
    const rows: CollectTag[] = [];
    refs.forEach((ref: CollectTagRef) => {
      for (const tag of this.allTags) {
        if (tag.id === ref.id) {
          const row: CollectTag = {
            id: tag.id,
            tagName: tag.tagName,
            check: false
          };
          if (tag.studentId !== undefined) {
            row.studentId = tag.studentId;
          }
          rows.push(row);
          break;
        }
      }
    });
    return rows;
  }

  private parseNewTagNames(text: string): string[] | null {
    const normalized = text.trim().replace(/，/g, ',');
    if (normalized.length === 0) {
      return [];
    }
    const out: string[] = [];
    const parts = normalized.split(',');
    for (const part of parts) {
      const name = part.trim();
      if (name.length === 0) {
        continue;
      }
      if (name.length > 16) {
        this.showToast('每个标签最多16个字');
        return null;
      }
      out.push(name);
    }
    return out;
  }

  private sourceTypeName(contentType: number): string {
    switch (contentType) {
      case 0:
        return '文字';
      case 1:
        return '文件';
      case 2:
        return '题';
      default:
        return '--';
    }
  }

  private typeColor(type: number): ResourceColor {
    return type === 0 ? Theme.WARN : Theme.PRIMARY;
  }

  private subjectColor(subject: string): ResourceColor {
    switch (subject) {
      case '语文':
        return '#FF443F';
      case '数学':
        return '#007EF9';
      case '英语':
        return '#00AD66';
      case '历史':
        return '#00C2E8';
      case '地理':
        return '#6C78F0';
      case '政治':
        return '#9ECF3F';
      case '物理':
        return '#D69600';
      case '化学':
        return '#A96B42';
      case '生物':
        return '#E17701';
      default:
        return Theme.PRIMARY;
    }
  }

  private formatTime(time: string): string {
    if (time.length === 0) {
      return '--';
    }
    const date = new Date(time);
    if (isNaN(date.getTime())) {
      return time.length >= 10 ? time.substring(0, 10).replace(/-/g, '.') : time;
    }
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const mm = month > 9 ? `${month}` : `0${month}`;
    const dd = day > 9 ? `${day}` : `0${day}`;
    return `${date.getFullYear()}.${mm}.${dd}`;
  }

  private questionType(type: number | undefined): string {
    switch (type) {
      case 0:
        return '单选';
      case 1:
        return '不定项';
      case 2:
        return '填空';
      case 3:
        return '简答';
      default:
        return '--';
    }
  }

  private questionTitle(content: CollectResourceContent): string {
    if (content.childList !== null && content.childList !== undefined && content.childList.length > 0) {
      let firstNo: string = '--';
      let lastNo: string = '--';
      let hasChild: boolean = false;
      content.childList.forEach((child: CollectResourceContent, idx: number) => {
        const currentNo: string = child.questionNumber === undefined ? '--' : child.questionNumber;
        if (idx === 0) {
          firstNo = currentNo;
        }
        lastNo = currentNo;
        hasChild = true;
      });
      if (hasChild) {
        return `题号：${firstNo} - ${lastNo}`;
      }
    }
    return `题号：${content.questionNumber ?? '--'}`;
  }

  private questionStem(content: CollectResourceContent): string {
    return content.questionStem ?? content.textContent ?? '';
  }

  private isBlankHtml(value: string | null | undefined): boolean {
    if (value === null || value === undefined) {
      return true;
    }
    const noTag = value.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, '').trim();
    return noTag.length === 0;
  }

  private attachmentExt(content: CollectResourceContent): string {
    const ext = content.attachmentExtraName ?? '';
    return ext.length > 0 ? ext.toLowerCase() : '';
  }

  private attachmentIcon(content: CollectResourceContent): Resource {
    const ext = this.attachmentExt(content);
    if (ext === '.pdf' || ext === '.doc' || ext === '.docx' || ext === '.ppt' || ext === '.pptx') {
      return $r('sys.symbol.doc_plaintext');
    }
    if (ext === '.mp4' || ext === '.mov' || ext === '.avi') {
      return $r('sys.symbol.play_circle');
    }
    if (ext === '.png' || ext === '.jpg' || ext === '.jpeg' || ext === '.gif') {
      return $r('sys.symbol.picture');
    }
    if (ext === '.mp3' || ext === '.wav' || ext === '.m4a') {
      return $r('sys.symbol.play_circle');
    }
    return $r('sys.symbol.paperclip');
  }

  private openAttachment(content: CollectResourceContent): void {
    const url = content.attachmentLinkAddress ?? '';
    if (url.length === 0) {
      this.showToast('附件地址为空');
      return;
    }
    const param: AttachmentViewerParam = {
      name: content.attachmentName ?? '附件',
      url: url,
      ext: content.attachmentExtraName ?? ''
    };
    Nav.push('attachmentViewer', param as object);
  }

  private openAttachmentEntity(att: AttachmentEntity): void {
    const url = att.attachmentLinkAddress;
    if (url.length === 0) {
      this.showToast('附件地址为空');
      return;
    }
    const param: AttachmentViewerParam = {
      name: att.attachmentName,
      url: url,
      ext: att.attachmentExtraName
    };
    Nav.push('attachmentViewer', param as object);
  }

  private questionAttachments(content: CollectResourceContent): AttachmentEntity[] {
    if (content.attachmentEntityList === null || content.attachmentEntityList === undefined) {
      return [];
    }
    return content.attachmentEntityList;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', (e as Error).message);
    }
  }

  @Builder
  teacherList() {
    Column({ space: 8 }) {
      Text('目 录')
        .fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 4 })

      List({ space: 6 }) {
        ForEach(this.teachers, (teacher: CollectTeacherItem, idx: number) => {
          ListItem() {
            this.teacherRow(teacher, idx)
          }
        }, (teacher: CollectTeacherItem) => `collect_teacher_${teacher.teacherUserId}_${teacher.subjectId}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 10, right: 10 })
      .contentEndOffset(Theme.TABBAR_CLEARANCE)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  teacherRow(teacher: CollectTeacherItem, idx: number) {
    Row({ space: 8 }) {
      Circle({ width: 8, height: 8 })
        .fill(this.subjectColor(teacher.subjectName))

      Column({ space: 2 }) {
        Text(teacher.userName)
          .fontSize(Theme.F_BODY)
          .fontWeight(this.selectedIdx === idx ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.selectedIdx === idx ? Theme.PRIMARY : Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(teacher.subjectName)
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(Theme.R_LG)
    .backgroundColor(this.selectedIdx === idx ? Theme.PRIMARY_SOFT : Color.Transparent)
    .onClick(() => {
      this.selectTeacher(idx);
    })
  }

  @Builder
  mobileTeacherTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.teachers, (teacher: CollectTeacherItem, idx: number) => {
          this.teacherPill(teacher, idx)
        }, (teacher: CollectTeacherItem) => `collect_pill_${teacher.teacherUserId}_${teacher.subjectId}`)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(46)
  }

  @Builder
  teacherPill(teacher: CollectTeacherItem, idx: number) {
    Text(`${teacher.userName} (${teacher.subjectName})`)
      .fontSize(Theme.F_SUB)
      .fontWeight(this.selectedIdx === idx ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selectedIdx === idx ? Color.White : Theme.TEXT)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .height(34)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.selectedIdx === idx ? Theme.PRIMARY : Theme.SURFACE)
      .backgroundBlurStyle(this.selectedIdx === idx ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR)
      .borderRadius(Theme.R_XL)
      .border({ width: 1, color: this.selectedIdx === idx ? Theme.PRIMARY : '#20000000' })
      .onClick(() => {
        this.selectTeacher(idx);
      })
  }

  @Builder
  contentHeader() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.currentTitle())
          .fontSize(Theme.F_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('筛选')
          .fontSize(Theme.F_SUB)
          .fontColor(this.selectedTagIds.length > 0 ? Color.White : Theme.PRIMARY)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.selectedTagIds.length > 0 ? Theme.PRIMARY : Theme.PRIMARY_SOFT)
          .borderRadius(Theme.R_XL)
          .onClick(() => {
            this.showTagPanel = !this.showTagPanel;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })

      Row({ space: 8 }) {
        ForEach(this.typeFilters, (filter: CollectTypeFilter) => {
          this.typeChip(filter)
        }, (filter: CollectTypeFilter) => `collect_type_${filter.id}`)
        Blank().layoutWeight(1)
        Text(`${this.items.length} 条`)
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
      }
      .width('100%')
      .height(42)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.showTagPanel) {
        this.tagFilterPanel()
      }
    }
    .width('100%')
  }

  @Builder
  typeChip(filter: CollectTypeFilter) {
    Text(filter.name)
      .fontSize(Theme.F_BODY)
      .fontWeight(this.containsNumber(this.selectedTypes, filter.id) ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.containsNumber(this.selectedTypes, filter.id) ? Color.White : Theme.TEXT_2)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(Theme.R_XL)
      .backgroundColor(this.containsNumber(this.selectedTypes, filter.id) ? Theme.PRIMARY : '#F0F2F5')
      .onClick(() => {
        this.toggleType(filter.id);
      })
  }

  @Builder
  tagFilterPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('标签筛选')
          .fontSize(Theme.F_SUB)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)
        Text('清空')
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_2)
          .onClick(() => {
            this.clearTagFilter();
          })
      }
      .width('100%')

      if (this.allTags.length === 0) {
        Text('暂无标签')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.TEXT_3)
          .width('100%')
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.allTags, (tag: CollectTag) => {
            this.filterTagChip(tag)
          }, (tag: CollectTag) => `filter_tag_${tag.id}`)
        }
        .width('100%')
      }

      Button('确定')
        .fontSize(Theme.F_SUB)
        .height(36)
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          this.applyTagFilter();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Theme.SURFACE)
    .borderRadius(Theme.R_LG)
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  filterTagChip(tag: CollectTag) {
    Text(tag.tagName)
      .fontSize(Theme.F_MINI)
      .fontColor(tag.check === true ? Color.White : Theme.TEXT_2)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(tag.check === true ? Theme.PRIMARY : '#F0F2F5')
      .borderRadius(Theme.R_XL)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.toggleTagFilter(tag);
      })
  }

  @Builder
  errorBanner() {
    if (this.errorText.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(18)
          .fontColor([Theme.DANGER])
        Text(this.errorText)
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.DANGER)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('重试')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.PRIMARY)
          .onClick(() => {
            this.retryCurrent();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#12E94B4B')
      .borderRadius(Theme.R_LG)
      .margin({ left: 16, right: 16, bottom: 8 })
    }
  }

  @Builder
  contentBody() {
    Column() {
      this.contentHeader()
      this.errorBanner()

      if (this.loadingItems) {
        LoadingView()
          .layoutWeight(1)
      } else if (!this.hasSelectedTeacher) {
        EmptyView({ text: '暂无数据' })
          .layoutWeight(1)
      } else if (this.items.length === 0) {
        EmptyView({ text: '暂无数据' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: CollectItem) => {
            ListItem() {
              this.collectCard(item)
            }
          }, (item: CollectItem) => this.itemKey(item))
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 12, right: 12 })
        .contentEndOffset(Theme.TABBAR_CLEARANCE)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  collectCard(item: CollectItem) {
    Column() {
      GlassCard({ innerPadding: 14 }) {
        Column({ space: 10 }) {
          this.cardHeader(item)
          this.tagRow(item)
          this.cardPreview(item)

          if (this.expandedKey === this.itemKey(item)) {
            Divider().color(Theme.DIVIDER)
            this.cardExpanded(item)
          }

          if (this.editingKey === this.itemKey(item)) {
            Divider().color(Theme.DIVIDER)
            this.tagEditor(item)
          }
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  cardHeader(item: CollectItem) {
    Row({ space: 8 }) {
      Text(this.sourceTypeName(item.contentType))
        .fontSize(Theme.F_MINI)
        .fontColor(Color.White)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.typeColor(item.content.type))
        .borderRadius(Theme.R_XL)

      Text('来源:')
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_3)

      Text(item.content.courseName)
        .fontSize(Theme.F_SUB)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.typeColor(item.content.type))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`收藏时间：${this.formatTime(item.content.createTime)}`)
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_3)
        .maxLines(1)

      SymbolGlyph(this.expandedKey === this.itemKey(item)
        ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([Theme.TEXT_3])
        .onClick(() => {
          const key = this.itemKey(item);
          this.expandedKey = this.expandedKey === key ? '' : key;
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  tagRow(item: CollectItem) {
    Flex({ wrap: FlexWrap.Wrap }) {
      if (item.content.tagList.length < 2) {
        Text('+')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.PRIMARY)
          .textAlign(TextAlign.Center)
          .width(36)
          .height(24)
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.R_XL)
          .margin({ right: 8, bottom: 6 })
          .onClick(() => {
            this.startEditTags(item);
          })
      }
      ForEach(item.content.tagList, (tag: CollectTag) => {
        Text(tag.tagName)
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.PRIMARY)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.R_XL)
          .margin({ right: 8, bottom: 6 })
          .onClick(() => {
            this.startEditTags(item);
          })
      }, (tag: CollectTag) => `card_tag_${this.itemKey(item)}_${tag.id}`)

      Blank().layoutWeight(1)

      Text(this.removingKey === this.itemKey(item) ? '删除中' : '删除')
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.DANGER)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#12E94B4B')
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          if (this.removingKey.length === 0) {
            this.removeItem(item);
          }
        })
    }
    .width('100%')
  }

  @Builder
  cardPreview(item: CollectItem) {
    if (item.contentType === 0) {
      this.textPreview(item.content.content)
    } else if (item.contentType === 1) {
      this.filePreview(item.content.content)
    } else {
      this.questionPreview(item.content.content)
    }
  }

  @Builder
  cardExpanded(item: CollectItem) {
    Column({ space: 10 }) {
      if (item.contentType === 2) {
        this.questionDetail(item.content)
      } else if (item.contentType === 1) {
        this.fileActions(item.content.content)
      } else {
        Text('文字内容')
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
      }
    }
    .width('100%')
  }

  @Builder
  textPreview(content: CollectResourceContent) {
    HtmlRichText({ html: content.textContent ?? '' })
  }

  @Builder
  filePreview(content: CollectResourceContent) {
    Row({ space: 10 }) {
      SymbolGlyph(this.attachmentIcon(content))
        .fontSize(24)
        .fontColor([Theme.PRIMARY])
      Column({ space: 4 }) {
        Text(content.attachmentName ?? '附件')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(content.attachmentExtraName ?? '文件')
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

  @Builder
  fileActions(content: CollectResourceContent) {
    Row({ space: 8 }) {
      SquishButton({
        onTap: () => {
          this.openAttachment(content);
        }
      }) {
        Text('预览附件')
          .fontSize(Theme.F_SUB)
          .fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor(Theme.PRIMARY)
          .borderRadius(Theme.R_XL)
      }
    }
    .width('100%')
  }

  @Builder
  questionPreview(content: CollectResourceContent) {
    Column({ space: 8 }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        this.infoTag(this.questionTitle(content), '#636F9F')
        if (content.questionScore !== undefined) {
          this.infoTag(`分数：${content.questionScore}`, Theme.TEXT_2)
        }
        this.infoTag(this.questionType(content.questionType), Theme.TEXT_2)
        if (!this.isBlankHtml(content.questionAnalysis)) {
          this.infoTag('解析', Theme.TEXT_2)
        }
        if (content.relevanceQuestionStem !== null && content.relevanceQuestionStem !== undefined) {
          this.infoTag('题干', Theme.TEXT_2)
        }
      }
      .width('100%')
      HtmlRichText({ html: this.questionStem(content) })
    }
    .width('100%')
  }

  @Builder
  questionDetail(resource: CollectResource) {
    Column({ space: 10 }) {
      if (resource.content.answer !== null && resource.content.answer !== undefined &&
        resource.content.answer.length > 0) {
        this.answerLine('答案', resource.content.answer, Theme.SUCCESS)
      }
      if (!this.isBlankHtml(resource.content.questionAnalysis)) {
        Column({ space: 4 }) {
          Text('解析')
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.WARN)
          HtmlRichText({ html: resource.content.questionAnalysis ?? '' })
        }
        .width('100%')
      }
      if (!this.isBlankHtml(resource.content.addToQuestionAnalysis)) {
        Column({ space: 4 }) {
          Text('追加解析')
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.WARN)
          HtmlRichText({ html: resource.content.addToQuestionAnalysis ?? '' })
        }
        .width('100%')
      }
      if (this.questionAttachments(resource.content).length > 0) {
        Text('附件')
          .fontSize(Theme.F_SUB)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_2)
        ForEach(this.questionAttachments(resource.content), (att: AttachmentEntity) => {
          this.attachmentEntityRow(att)
        }, (att: AttachmentEntity) => `q_att_${att.id}`)
      }
    }
    .width('100%')
  }

  @Builder
  attachmentEntityRow(att: AttachmentEntity) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.paperclip'))
        .fontSize(18)
        .fontColor([Theme.PRIMARY])
      Text(att.attachmentName)
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(att.attachmentExtraName)
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_3)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .onClick(() => {
      this.openAttachmentEntity(att);
    })
  }

  @Builder
  infoTag(text: string, color: ResourceColor) {
    Text(text)
      .fontSize(Theme.F_MINI)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor('#F0F2F5')
      .borderRadius(Theme.R_XL)
      .margin({ right: 6, bottom: 6 })
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  answerLine(label: string, value: string, color: ResourceColor) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(Theme.F_SUB)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(value)
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  tagEditor(item: CollectItem) {
    Column({ space: 10 }) {
      TextInput({ placeholder: '请输入新标签，多个标签用逗号隔开', text: this.newTagText })
        .height(38)
        .borderRadius(Theme.R_LG)
        .backgroundColor('#F0F2F5')
        .fontSize(Theme.F_SUB)
        .onChange((value: string) => {
          this.newTagText = value;
        })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.allTags, (tag: CollectTag) => {
          this.editTagChip(tag)
        }, (tag: CollectTag) => `edit_tag_${tag.id}`)
      }
      .width('100%')

      Row({ space: 8 }) {
        Blank().layoutWeight(1)
        Text('取消')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.TEXT_2)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#F0F2F5')
          .borderRadius(Theme.R_XL)
          .onClick(() => {
            this.cancelEditTags();
          })
        Text('确定')
          .fontSize(Theme.F_SUB)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(Theme.PRIMARY)
          .borderRadius(Theme.R_XL)
          .onClick(() => {
            this.saveTags(item);
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  editTagChip(tag: CollectTag) {
    Text(tag.tagName)
      .fontSize(Theme.F_MINI)
      .fontColor(tag.check === true ? Color.White : Theme.TEXT_2)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(tag.check === true ? Theme.PRIMARY : '#F0F2F5')
      .borderRadius(Theme.R_XL)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.toggleEditTag(tag);
      })
  }

  @Builder
  wideModeLayout() {
    Row() {
      Column() {
        this.teacherList()
      }
      .width('32%')
      .constraintSize({ minWidth: 220, maxWidth: 360 })
      .height('100%')
      .backgroundColor(Theme.BG_CREAM_DEEP)

      Divider().vertical(true).color(Theme.DIVIDER).height('100%')

      Column() {
        this.contentBody()
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
      this.mobileTeacherTabs()
      Divider().color(Theme.DIVIDER).width('100%')
      this.contentBody()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Text('收藏')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ top: this.ui.topSafeVp + 12, left: 20, right: 20, bottom: 8 })

      if (this.loadingCatalog) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.teachers.length === 0 && this.errorText.length === 0) {
        EmptyView({ text: '暂无数据' })
          .layoutWeight(1)
      } else if (this.ui.isWide) {
        this.wideModeLayout()
      } else {
        this.narrowModeLayout()
      }
    }
    .width('100%')
    .height('100%')
  }
}
