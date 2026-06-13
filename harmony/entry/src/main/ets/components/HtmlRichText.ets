// quill 受限 HTML → ArkUI 原生渲染。
// 支持标签：p, h1-h6, strong/b, em/i, u, s/del, span[style color/font-size],
// img, ol/ul/li, blockquote, sub/sup, a, br。
// 解析失败或遇到不支持的复杂结构时整段回退 RichText 组件。
// titleLevel 非零时作为标题跳转锚点使用（CourseDetailPage 侧栏目录）。

import { Theme } from '../theme/Theme';
import { ApiClient } from '../net/ApiClient';
import { SettingsStore } from '../store/SettingsStore';

interface ParsedNode {
  tag: string;
  attrs: Record<string, string>;
  children: ParsedNode[];
  text: string;
}

function parseSimpleHtml(html: string): ParsedNode[] {
  const nodes: ParsedNode[] = [];
  let pos = 0;
  const len = html.length;

  while (pos < len) {
    if (html.charAt(pos) === '<') {
      const closeIdx = html.indexOf('>', pos);
      if (closeIdx < 0) {
        nodes.push({ tag: '', attrs: {}, children: [], text: html.substring(pos) });
        break;
      }
      const tagContent = html.substring(pos + 1, closeIdx);

      // closing tag
      if (tagContent.charAt(0) === '/') {
        pos = closeIdx + 1;
        break;
      }

      // self-closing tags
      const selfClose = tagContent.endsWith('/') || tagContent.toLowerCase().startsWith('br') ||
        tagContent.toLowerCase().startsWith('img') || tagContent.toLowerCase().startsWith('hr');

      const spaceIdx = tagContent.indexOf(' ');
      let rawTag: string;
      let attrStr: string;
      if (spaceIdx > 0) {
        rawTag = tagContent.substring(0, spaceIdx);
        attrStr = tagContent.substring(spaceIdx + 1).replace(/\/$/, '').trim();
      } else {
        rawTag = tagContent.replace(/\/$/, '');
        attrStr = '';
      }
      const tag = rawTag.toLowerCase();
      const attrs = parseAttrs(attrStr);

      pos = closeIdx + 1;

      if (selfClose || tag === 'br' || tag === 'hr' || tag === 'img') {
        nodes.push({ tag, attrs, children: [], text: '' });
      } else {
        const saved = pos;
        const children = parseChildren(html, tag, pos);
        const endTag = `</${tag}>`;
        const endIdx = html.toLowerCase().indexOf(endTag, saved);
        if (endIdx >= 0) {
          pos = endIdx + endTag.length;
        }
        nodes.push({ tag, attrs, children, text: '' });
      }
    } else {
      const nextTag = html.indexOf('<', pos);
      const end = nextTag >= 0 ? nextTag : len;
      const text = html.substring(pos, end);
      if (text.length > 0) {
        nodes.push({ tag: '', attrs: {}, children: [], text: decodeEntities(text) });
      }
      pos = end;
    }
  }
  return nodes;
}

function parseChildren(html: string, parentTag: string, startPos: number): ParsedNode[] {
  const endTag = `</${parentTag}>`;
  const endIdx = html.toLowerCase().indexOf(endTag, startPos);
  const innerEnd = endIdx >= 0 ? endIdx : html.length;
  const inner = html.substring(startPos, innerEnd);
  return parseSimpleHtml(inner);
}

function parseAttrs(s: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (s.length === 0) {
    return out;
  }
  const re = /(\w[\w-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+)))?/g;
  let m: RegExpExecArray | null = re.exec(s);
  while (m !== null) {
    const key = m[1];
    const val = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] ?? ''));
    out[key] = val;
    m = re.exec(s);
  }
  return out;
}

function decodeEntities(s: string): string {
  return s.replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}

function extractStyleProp(style: string, prop: string): string {
  const idx = style.indexOf(prop);
  if (idx < 0) {
    return '';
  }
  const colonIdx = style.indexOf(':', idx);
  if (colonIdx < 0) {
    return '';
  }
  const semiIdx = style.indexOf(';', colonIdx);
  const end = semiIdx >= 0 ? semiIdx : style.length;
  return style.substring(colonIdx + 1, end).trim();
}

function collectText(nodes: ParsedNode[]): string {
  let out = '';
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    if (n.text.length > 0) {
      out += n.text;
    }
    if (n.tag === 'br') {
      out += '\n';
    }
    if (n.children.length > 0) {
      out += collectText(n.children);
    }
  }
  return out;
}

interface ImageInfo {
  src: string;
  width: number;
  height: number;
}

function collectImages(nodes: ParsedNode[]): ImageInfo[] {
  const imgs: ImageInfo[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    if (n.tag === 'img' && n.attrs['src']) {
      const w = parseInt(n.attrs['width'] ?? '0');
      const h = parseInt(n.attrs['height'] ?? '0');
      imgs.push({
        src: ApiClient.assetUrl(n.attrs['src']),
        width: isNaN(w) || w <= 0 ? 0 : w,
        height: isNaN(h) || h <= 0 ? 0 : h
      });
    }
    if (n.children.length > 0) {
      const sub = collectImages(n.children);
      for (let j = 0; j < sub.length; j++) {
        imgs.push(sub[j]);
      }
    }
  }
  return imgs;
}

interface TextSegment {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strikethrough: boolean;
  color: string;
  fontSize: number;
}

function collectSegments(nodes: ParsedNode[], inherited: TextSegment): TextSegment[] {
  const segs: TextSegment[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    if (n.text.length > 0) {
      segs.push({
        text: n.text,
        bold: inherited.bold,
        italic: inherited.italic,
        underline: inherited.underline,
        strikethrough: inherited.strikethrough,
        color: inherited.color,
        fontSize: inherited.fontSize
      });
      continue;
    }
    if (n.tag === 'br') {
      segs.push({
        text: '\n',
        bold: inherited.bold,
        italic: inherited.italic,
        underline: inherited.underline,
        strikethrough: inherited.strikethrough,
        color: inherited.color,
        fontSize: inherited.fontSize
      });
      continue;
    }
    const next: TextSegment = {
      text: '',
      bold: inherited.bold || n.tag === 'strong' || n.tag === 'b',
      italic: inherited.italic || n.tag === 'em' || n.tag === 'i',
      underline: inherited.underline || n.tag === 'u',
      strikethrough: inherited.strikethrough || n.tag === 's' || n.tag === 'del',
      color: inherited.color,
      fontSize: inherited.fontSize
    };
    if (n.tag === 'span' && n.attrs['style']) {
      const c = extractStyleProp(n.attrs['style'], 'color');
      if (c.length > 0) {
        next.color = c;
      }
      const fs = extractStyleProp(n.attrs['style'], 'font-size');
      if (fs.length > 0) {
        const px = parseInt(fs);
        if (!isNaN(px) && px > 0) {
          next.fontSize = px;
        }
      }
    }
    if (n.children.length > 0) {
      const childSegs = collectSegments(n.children, next);
      for (let j = 0; j < childSegs.length; j++) {
        segs.push(childSegs[j]);
      }
    }
  }
  return segs;
}

// parsed block: either a paragraph with text segments + inline images, or a standalone image, or a list
interface ContentParagraph {
  type: 'text' | 'image' | 'list' | 'blockquote';
  segments: TextSegment[];
  images: ImageInfo[];
  headingLevel: number;
  listItems: string[];
  ordered: boolean;
}

function nodesToParagraphs(nodes: ParsedNode[]): ContentParagraph[] {
  const paras: ContentParagraph[] = [];
  const defaultSeg: TextSegment = {
    text: '', bold: false, italic: false, underline: false,
    strikethrough: false, color: '', fontSize: 0
  };

  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];

    // plain text at top level
    if (n.tag === '' && n.text.trim().length > 0) {
      paras.push({
        type: 'text', segments: [{
          text: n.text, bold: defaultSeg.bold, italic: defaultSeg.italic,
          underline: defaultSeg.underline, strikethrough: defaultSeg.strikethrough,
          color: defaultSeg.color, fontSize: defaultSeg.fontSize
        }],
        images: [], headingLevel: 0, listItems: [], ordered: false
      });
      continue;
    }

    // headings
    if (n.tag.length === 2 && n.tag.charAt(0) === 'h') {
      const level = parseInt(n.tag.charAt(1));
      if (!isNaN(level) && level >= 1 && level <= 6) {
        const segs = collectSegments(n.children, {
          text: defaultSeg.text, bold: true, italic: defaultSeg.italic,
          underline: defaultSeg.underline, strikethrough: defaultSeg.strikethrough,
          color: defaultSeg.color, fontSize: defaultSeg.fontSize
        });
        paras.push({
          type: 'text', segments: segs, images: collectImages(n.children),
          headingLevel: level, listItems: [], ordered: false
        });
        continue;
      }
    }

    // paragraph
    if (n.tag === 'p' || n.tag === 'div') {
      const segs = collectSegments(n.children, defaultSeg);
      const imgs = collectImages(n.children);
      if (segs.length > 0 || imgs.length > 0) {
        paras.push({
          type: 'text', segments: segs, images: imgs,
          headingLevel: 0, listItems: [], ordered: false
        });
      }
      continue;
    }

    // standalone image
    if (n.tag === 'img' && n.attrs['src']) {
      const info: ImageInfo = {
        src: ApiClient.assetUrl(n.attrs['src']),
        width: parseInt(n.attrs['width'] ?? '0') || 0,
        height: parseInt(n.attrs['height'] ?? '0') || 0
      };
      paras.push({
        type: 'image', segments: [], images: [info],
        headingLevel: 0, listItems: [], ordered: false
      });
      continue;
    }

    // lists
    if (n.tag === 'ol' || n.tag === 'ul') {
      const items: string[] = [];
      for (let j = 0; j < n.children.length; j++) {
        const li = n.children[j];
        if (li.tag === 'li') {
          items.push(collectText(li.children));
        }
      }
      paras.push({
        type: 'list', segments: [], images: [], headingLevel: 0,
        listItems: items, ordered: n.tag === 'ol'
      });
      continue;
    }

    // blockquote
    if (n.tag === 'blockquote') {
      const segs = collectSegments(n.children, defaultSeg);
      paras.push({
        type: 'blockquote', segments: segs, images: [],
        headingLevel: 0, listItems: [], ordered: false
      });
      continue;
    }

    // inline formatting tags at top level: wrap as paragraph
    if (['strong', 'b', 'em', 'i', 'u', 's', 'del', 'span', 'a', 'sub', 'sup'].indexOf(n.tag) >= 0) {
      const segs = collectSegments([n], defaultSeg);
      paras.push({
        type: 'text', segments: segs, images: [],
        headingLevel: 0, listItems: [], ordered: false
      });
      continue;
    }
  }
  return paras;
}

@ComponentV2
export struct HtmlRichText {
  @Param html: string = '';
  @Param baseFontSize: number = Theme.F_BODY;
  @Param @Once maxImageWidth: number = 600;

  @Local private paras: ContentParagraph[] = [];
  @Local private fallback: boolean = false;

  @Monitor('html')
  onHtmlChange(): void {
    this.parseHtml();
  }

  aboutToAppear(): void {
    this.parseHtml();
  }

  private parseHtml(): void {
    const raw = this.html.trim();
    if (raw.length === 0) {
      this.paras = [];
      this.fallback = false;
      return;
    }
    try {
      const nodes = parseSimpleHtml(raw);
      this.paras = nodesToParagraphs(nodes);
      if (this.paras.length === 0 && raw.length > 0) {
        this.fallback = true;
      } else {
        this.fallback = false;
      }
    } catch (e) {
      this.fallback = true;
    }
  }

  @Builder
  segmentSpans(segs: TextSegment[]) {
    Text() {
      ForEach(segs, (seg: TextSegment, idx: number) => {
        Span(seg.text)
          .fontSize(seg.fontSize > 0 ? seg.fontSize : this.baseFontSize)
          .fontWeight(seg.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
          .decoration(seg.underline ? {
            type: TextDecorationType.Underline,
            color: seg.color.length > 0 ? seg.color : Theme.TEXT
          } : (seg.strikethrough ? {
            type: TextDecorationType.LineThrough,
            color: seg.color.length > 0 ? seg.color : Theme.TEXT_2
          } : { type: TextDecorationType.None }))
          .fontColor(seg.color.length > 0 ? seg.color : Theme.TEXT)
      }, (_seg: TextSegment, idx: number) => `seg_${idx}`)
    }
    .width('100%')
    .lineHeight(this.baseFontSize * 1.7)
  }

  @Builder
  imageBlock(info: ImageInfo) {
    Image(info.src)
      .width(info.width > 0 ? Math.min(info.width, this.maxImageWidth) : '100%')
      .objectFit(ImageFit.Contain)
      .borderRadius(Theme.R_SM)
      .draggable(false)
      .colorFilter(SettingsStore.instance.enableImageInvert
        ? [
          -1, 0, 0, 0, 1,
          0, -1, 0, 0, 1,
          0, 0, -1, 0, 1,
          0, 0, 0, 1, 0
        ] : undefined)
  }

  build() {
    if (this.fallback) {
      RichText(this.html)
        .width('100%')
    } else {
      Column({ space: 8 }) {
        ForEach(this.paras, (p: ContentParagraph, pi: number) => {
          if (p.type === 'text') {
            Column({ space: 4 }) {
              if (p.segments.length > 0) {
                Text() {
                  ForEach(p.segments, (seg: TextSegment, si: number) => {
                    Span(seg.text)
                      .fontSize(p.headingLevel > 0
                        ? (p.headingLevel === 1 ? 22 : (p.headingLevel === 2 ? 19 : 17))
                        : (seg.fontSize > 0 ? seg.fontSize : this.baseFontSize))
                      .fontWeight(seg.bold || p.headingLevel > 0 ? FontWeight.Bold : FontWeight.Normal)
                      .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
                      .decoration(seg.underline ? {
                        type: TextDecorationType.Underline,
                        color: seg.color.length > 0 ? seg.color : Theme.TEXT
                      } : (seg.strikethrough ? {
                        type: TextDecorationType.LineThrough,
                        color: seg.color.length > 0 ? seg.color : Theme.TEXT_2
                      } : { type: TextDecorationType.None }))
                      .fontColor(seg.color.length > 0 ? seg.color : Theme.TEXT)
                  }, (_s: TextSegment, si: number) => `p${pi}_s${si}`)
                }
                .width('100%')
                .lineHeight(p.headingLevel > 0 ? 32 : this.baseFontSize * 1.7)
              }
              ForEach(p.images, (img: ImageInfo, ii: number) => {
                this.imageBlock(img)
              }, (_img: ImageInfo, ii: number) => `p${pi}_img${ii}`)
            }
          } else if (p.type === 'image') {
            ForEach(p.images, (img: ImageInfo, ii: number) => {
              this.imageBlock(img)
            }, (_img: ImageInfo, ii: number) => `img_${pi}_${ii}`)
          } else if (p.type === 'list') {
            Column({ space: 4 }) {
              ForEach(p.listItems, (item: string, li: number) => {
                Row({ space: 8 }) {
                  Text(p.ordered ? `${li + 1}.` : '•')
                    .fontSize(this.baseFontSize)
                    .fontColor(Theme.TEXT_2)
                    .width(p.ordered ? 24 : 14)
                    .textAlign(TextAlign.End)
                  Text(item)
                    .fontSize(this.baseFontSize)
                    .fontColor(Theme.TEXT)
                    .layoutWeight(1)
                    .lineHeight(this.baseFontSize * 1.7)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }, (_item: string, li: number) => `li_${pi}_${li}`)
            }
          } else if (p.type === 'blockquote') {
            Row() {
              Column()
                .width(3)
                .height('100%')
                .backgroundColor(Theme.PRIMARY_SOFT)
                .borderRadius(2)
              Column() {
                if (p.segments.length > 0) {
                  this.segmentSpans(p.segments)
                }
              }
              .layoutWeight(1)
              .padding({ left: 12 })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6, left: 4 })
          }
        }, (_p: ContentParagraph, pi: number) => `para_${pi}`)
      }
      .width('100%')
    }
  }
}
