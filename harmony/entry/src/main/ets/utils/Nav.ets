// 全局导航栈：单 Navigation 模式，所有二级页都是 NavDestination。

export class Nav {
  static readonly stack: NavPathStack = new NavPathStack();

  static push(name: string, param: object | string | number | null): void {
    Nav.stack.pushPathByName(name, param);
  }

  static pop(): void {
    Nav.stack.pop();
  }
}
