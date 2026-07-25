import { MemberSetupFlowViewModel } from './Members/MemberSetup/MemberSetupFlowViewModel';

/**
 * 成员建档/模块维护流程在 jump 前挂到根路由；宿主页 aboutToAppear 读取。
 * 避免把 ViewModel 塞进 NavPathStack 参数（ArkTS 路由参数宜为轻量值）。
 */
export class HomeSetupFlowHolder {
  private static flowVm?: MemberSetupFlowViewModel;

  static set(flowVm: MemberSetupFlowViewModel): void {
    HomeSetupFlowHolder.flowVm = flowVm;
  }

  static peek(): MemberSetupFlowViewModel | undefined {
    return HomeSetupFlowHolder.flowVm;
  }

  static clear(): void {
    HomeSetupFlowHolder.flowVm = undefined;
  }
}
