import { promptAction } from '@kit.ArkUI';
import { Member } from '../../../../../Core/Domain/Entities/Member';
import { MemberRelationshipCatalog } from '../MemberRelationshipCatalog';
import { MemberSetupFlowViewModel } from './MemberSetupFlowViewModel';
import { MemberSetupModule } from './MemberSetupDraft';

/**
 * 成员建档 / 模块维护页。步骤态机（无嵌套 Navigation），对齐 iOS SetupFlow 核心路径。
 * Sheet/表单布局参考 demos AddressFormSheet / EditPersonalCenter 的分段表单风格。
 */
@Component
export struct MemberSetupFlowPage {
  flowVm?: MemberSetupFlowViewModel;
  onClose: () => void = () => {};
  onFinished: (member: Member) => void = (_m: Member) => {};

  @State private tick: number = 0;
  @State private step: string = 'nameBirth';
  @State private name: string = '';
  @State private birthDate: string = '';
  @State private relationshipCode: string = 'self';
  @State private gender: string = '';
  @State private selectedCodes: string[] = [];
  @State private completedCodes: string[] = [];
  @State private isBusy: boolean = false;
  @State private relationshipCodes: string[] = MemberRelationshipCatalog.flatCodes();

  aboutToAppear(): void {
    const vm = this.flowVm;
    if (!vm) {
      return;
    }
    vm.setOnChanged(() => {
      this.syncFromVm();
    });
    this.syncFromVm();
    if (vm.mode === 'maintain') {
      vm.loadExistingModuleSettingsIfNeeded();
    }
  }

  private syncFromVm(): void {
    const vm = this.flowVm;
    if (!vm) {
      return;
    }
    this.step = vm.step;
    this.name = vm.draft.name;
    this.birthDate = vm.draft.birthDate ?? '';
    this.relationshipCode = vm.draft.relationshipCode;
    this.gender = vm.draft.gender;
    this.selectedCodes = vm.selectedModuleCodes.slice();
    this.completedCodes = vm.completedModuleCodes.slice();
    this.isBusy = vm.isSavingMember
      || vm.isPersistingModules
      || vm.isLoadingExistingModules;
    this.tick += 1;
    if (vm.alertMessage.length > 0) {
      promptAction.showToast({ message: vm.alertMessage, duration: 2500 });
      vm.clearAlert();
    }
  }

  private isSelected(code: string): boolean {
    return this.selectedCodes.indexOf(code) >= 0;
  }

  private isCompleted(code: string): boolean {
    return this.completedCodes.indexOf(code) >= 0;
  }

  private async handleCreateNext(): Promise<void> {
    const vm = this.flowVm;
    if (!vm) {
      return;
    }
    const ok = await vm.createMember();
    if (!ok) {
      return;
    }
    const enabled = await vm.enableDefaultMedicalModuleForCreatedMember();
    if (!enabled) {
      return;
    }
    const member = vm.createdMember;
    if (member) {
      this.onFinished(member);
    }
    this.onClose();
  }

  private async handleFinish(): Promise<void> {
    const vm = this.flowVm;
    if (!vm) {
      return;
    }
    const ok = await vm.finish();
    if (!ok) {
      return;
    }
    const member = vm.createdMember;
    if (member) {
      this.onFinished(member);
    }
    this.onClose();
  }

  @Builder
  headerBar(title: string, showBack: boolean) {
    Row() {
      if (showBack) {
        Text('返回')
          .fontSize(15)
          .fontColor('#0A84FF')
          .onClick(() => {
            const vm = this.flowVm;
            if (!vm) {
              this.onClose();
              return;
            }
            if (this.step === 'birthDate') {
              vm.backFromBirthDate();
            } else if (this.step === 'relationship') {
              vm.backFromRelationship();
            } else {
              this.onClose();
            }
          })
      } else {
        Text('关闭')
          .fontSize(15)
          .fontColor('#0A84FF')
          .onClick(() => {
            this.onClose();
          })
      }
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      if (this.isBusy) {
        LoadingProgress().width(20).height(20)
      } else {
        Blank().width(36)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  nameBirthStep() {
    Column({ space: 16 }) {
      this.headerBar('添加成员', false)
      Text('姓名')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')
        .padding({ left: 16, right: 16 })
      TextInput({ text: this.name, placeholder: '请输入成员姓名' })
        .height(44)
        .margin({ left: 16, right: 16 })
        .backgroundColor('#F2F2F7')
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.flowVm?.setName(v);
        })
      Blank().layoutWeight(1)
      Button('下一步')
        .width('90%')
        .height(44)
        .enabled(this.name.trim().length > 0 && !this.isBusy)
        .onClick(() => {
          this.flowVm?.goToBirthDate();
        })
      Blank().height(24)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  birthDateStep() {
    Column({ space: 16 }) {
      this.headerBar('出生日期', true)
      Text('可选，格式 YYYY-MM-DD')
        .fontSize(13)
        .fontColor('#888888')
        .width('100%')
        .padding({ left: 16, right: 16 })
      TextInput({ text: this.birthDate, placeholder: '例如 1990-01-01' })
        .height(44)
        .margin({ left: 16, right: 16 })
        .backgroundColor('#F2F2F7')
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.flowVm?.setBirthDate(v.trim());
        })
      Blank().layoutWeight(1)
      Row({ space: 12 }) {
        Button('跳过')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#F2F2F7')
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.flowVm?.setBirthDate('');
            this.flowVm?.goToRelationship();
          })
        Button('下一步')
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.flowVm?.goToRelationship();
          })
      }
      .width('90%')
      Blank().height(24)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  relationshipStep() {
    Column({ space: 12 }) {
      this.headerBar('关系与性别', true)
      Text('亲属关系')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')
        .padding({ left: 16, right: 16 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.relationshipCodes, (code: string) => {
          Text(MemberRelationshipCatalog.option(code).title)
            .fontSize(13)
            .fontColor(this.relationshipCode === code ? Color.White : '#1C1C1E')
            .backgroundColor(this.relationshipCode === code ? '#0A84FF' : '#F2F2F7')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(10)
            .margin({ left: 8, right: 8, bottom: 8 })
            .onClick(() => {
              this.flowVm?.selectRelationship(code);
            })
        }, (code: string) => `${code}-${this.tick}`)
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Text('性别')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')
        .padding({ left: 16, right: 16 })
      Row({ space: 12 }) {
        Text('男')
          .fontSize(14)
          .fontColor(this.gender === 'male' ? Color.White : '#1C1C1E')
          .backgroundColor(this.gender === 'male' ? '#0A84FF' : '#F2F2F7')
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .borderRadius(10)
          .onClick(() => {
            this.flowVm?.setGender('male');
          })
        Text('女')
          .fontSize(14)
          .fontColor(this.gender === 'female' ? Color.White : '#1C1C1E')
          .backgroundColor(this.gender === 'female' ? '#0A84FF' : '#F2F2F7')
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .borderRadius(10)
          .onClick(() => {
            this.flowVm?.setGender('female');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Blank().layoutWeight(1)
      Button(this.isBusy ? '创建中…' : '创建并开通医疗')
        .width('90%')
        .height(44)
        .enabled(MemberRelationshipCatalog.isSelectableGender(this.gender) && !this.isBusy)
        .onClick(() => {
          this.handleCreateNext();
        })
      Blank().height(24)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  modulesStep() {
    Column({ space: 12 }) {
      this.headerBar('模块维护', false)
      if (this.flowVm?.createdMember) {
        Text(`${this.flowVm.createdMember.name} · ${MemberRelationshipCatalog.displayTitle(this.flowVm.createdMember.relationship)}`)
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
          .padding({ left: 16, right: 16 })
      }
      ForEach(MemberSetupModule.allVisible(), (module: MemberSetupModule) => {
        Row() {
          Column({ space: 4 }) {
            Text(module.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C1C1E')
            Text(module.subtitle)
              .fontSize(12)
              .fontColor('#888888')
            if (this.isCompleted(module.rawValue)) {
              Text('已完善')
                .fontSize(11)
                .fontColor('#34C759')
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.isSelected(module.rawValue) })
            .selectedColor('#0A84FF')
            .onChange((isOn: boolean) => {
              const currently = this.isSelected(module.rawValue);
              if (isOn !== currently) {
                this.flowVm?.toggleModule(module);
              }
            })
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor('#F7F7F8')
        .borderRadius(12)
      }, (module: MemberSetupModule) => `${module.rawValue}-${this.tick}`)

      Blank().layoutWeight(1)
      Row({ space: 12 }) {
        Button('暂不完善')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#F2F2F7')
          .fontColor('#1C1C1E')
          .enabled(!this.isBusy && (this.flowVm?.canFinish === true))
          .onClick(() => {
            this.handleFinish();
          })
        Button('完成')
          .layoutWeight(1)
          .height(44)
          .enabled(!this.isBusy && (this.flowVm?.canFinish === true))
          .onClick(() => {
            this.handleFinish();
          })
      }
      .width('90%')
      Blank().height(24)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (!this.flowVm) {
        Text('流程未初始化')
          .fontSize(14)
          .fontColor('#888888')
      } else if (this.step === 'nameBirth') {
        this.nameBirthStep()
      } else if (this.step === 'birthDate') {
        this.birthDateStep()
      } else if (this.step === 'relationship') {
        this.relationshipStep()
      } else {
        this.modulesStep()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
