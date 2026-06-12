// 目录树与红点模型。
// 目录树：/api/student/catalog/entity/{teacherUserId}（course 侧）
//        /api/student/paper/catalog/entity/{teacherUserId}（paper/考试 侧）
// 红点：  /api/catalog/reddot 与 /api/paper/catalog/reddot

export interface CatalogNode {
  id: number;
  catalogName: string;
  catalogParentId: number;
  creator: number;
  informTag: number;
  catalogIdPath: string;        // 形如 "1-138646-138647"
  catalogNamePath: string;
  classify: number;
  catalogIndex: number;
  third: number;
  childList: CatalogNode[] | null;
  newCourseFlag?: boolean;
}

// 红点集合：服务端维护的「有更新」的目录/课件/教师 id 集合
export interface ReddotSets {
  catalogIds: number[] | null;
  courseIds: number[] | null;
  teacherIds: number[] | null;
}

// paper 侧红点字段名不同（paperIds）
export interface PaperReddotSets {
  catalogIds: number[] | null;
  paperIds: number[] | null;
  teacherIds: number[] | null;
}
