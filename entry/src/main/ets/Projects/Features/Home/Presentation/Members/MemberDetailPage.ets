import { promptAction } from '@kit.ArkUI';
import { Member } from '../../../../Core/Domain/Entities/Member';
import { ManageHomeMemberUseCase } from '../../Application/ManageHomeMemberUseCase';
import { MemberRelationshipCatalog } from './MemberRelationshipCatalog';
import { Logger } from '../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../Foundation/Logging/LogModule';

/** 成员详情页。复刻 iOS MemberDetailView 的头卡、资料和操作入口。 */
@Component
export struct MemberDetailPage {
  member?: Member;
  memberUseCase?: ManageHomeMemberUseCase;
  onClose: () => void = () => {};
  onEdit: () => void = () => {};
  onMaintainModules: () => void = () => {};
  onDeleted: () => void = () => {};
  @StorageProp('topRectHeight') private topRectHeightPx: number = 0;
  @State private isDeleting: boolean = false;

  aboutToAppear(): void {
    const fields = new LogFields();
    fields.code = this.member?.id ?? 'none';
    fields.operation = 'member_detail_page';
    fields.detail = `hasMember=${this.member !== undefined}, nameLength=${this.member?.name.length ?? 0}`;
    Logger.info('member.detail.page_appeared', LogModule.HOME, fields);
  }

  aboutToDisappear(): void {
    const fields = new LogFields();
    fields.code = this.member?.id ?? 'none';
    fields.operation = 'member_detail_page';
    Logger.info('member.detail.page_disappeared', LogModule.HOME, fields);
  }

  private displayName(): string {
    return this.member?.name.length ? this.member.name : '成员';
  }

  private genderTitle(): string {
    const gender = this.member?.gender.toLowerCase();
    if (gender === 'male') return '男';
    if (gender === 'female') return '女';
    return '未设置';
  }

  private deleteTitle(): string {
    return this.member?.effectiveBinding.canDelete ? '删除成员' : '解除绑定';
  }

  private topSafeInset(): number {
    if (this.topRectHeightPx > 0) {
      return this.getUIContext().px2vp(this.topRectHeightPx);
    }
    // 避让区尚未回调时保留常见状态栏高度，避免首帧按钮落入状态栏。
    return 24;
  }

  private confirmDelete(): void {
    const member = this.member;
    const useCase = this.memberUseCase;
    if (!member || !useCase || this.isDeleting) return;
    promptAction.showDialog({
      title: this.deleteTitle(),
      message: `确定要${this.deleteTitle()}“${this.displayName()}”吗？此操作无法撤销。`,
      buttons: [{ text: '取消', color: '#0A84FF' }, { text: this.deleteTitle(), color: '#FF3B30' }]
    }).then((result) => {
      if (result.index === 1) this.deleteMember(member, useCase);
    }).catch(() => {});
  }

  private async deleteMember(member: Member, useCase: ManageHomeMemberUseCase): Promise<void> {
    this.isDeleting = true;
    try {
      await useCase.delete(member);
      this.onDeleted();
    } catch (e) {
      promptAction.showToast({ message: `操作失败：${e}`, duration: 2500 });
    } finally {
      this.isDeleting = false;
    }
  }

  @Builder
  infoRow(title: string, value: string) {
    Row() {
      Text(title).fontSize(14).fontColor('#666666')
      Text(value.length > 0 ? value : '暂无')
        .fontSize(14)
        .fontColor('#1C1C1E')
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Text('关闭')
          .fontSize(15)
          .fontColor('#0A84FF')
          .width(48)
          .onClick(() => this.onClose())
        Text('成员详情').fontSize(17).fontWeight(FontWeight.Medium).textAlign(TextAlign.Center).layoutWeight(1)
        Text('编辑')
          .fontSize(15)
          .fontColor(this.member?.effectiveBinding.canEdit ? '#0A84FF' : '#9BA0A6')
          .width(48)
          .textAlign(TextAlign.End)
          .onClick(() => {
            const fields = new LogFields();
            fields.code = this.member?.id ?? 'none';
            fields.operation = 'member_detail_edit';
            fields.detail = `canEdit=${this.member?.effectiveBinding.canEdit ?? false}`;
            Logger.info('member.detail.edit_clicked', LogModule.HOME, fields);
            if (this.member?.effectiveBinding.canEdit) this.onEdit();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.topSafeInset() + 12, bottom: 12 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Text(this.displayName().substring(0, 1))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0A84FF')
              .width(76)
              .height(76)
              .textAlign(TextAlign.Center)
              .padding({ top: 18 })
              .backgroundColor('#EAF3FF')
              .borderRadius(38)
            Text(this.displayName()).fontSize(22).fontWeight(FontWeight.Bold)
            Text(`${MemberRelationshipCatalog.displayTitle(this.member?.relationship ?? 'other')} · ${this.genderTitle()}`)
              .fontSize(14).fontColor('#666666')
          }
          .width('100%')
          .padding(22)
          .backgroundColor(Color.White)
          .borderRadius(20)

          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('▦').fontSize(18).fontColor('#0A84FF')
              Text('模块总览').fontSize(16).fontWeight(FontWeight.Medium)
            }.width('100%')
            Row() {
              Column({ space: 4 }) {
                Text('医疗').fontSize(15).fontWeight(FontWeight.Medium)
                Text('病历、体检、检查和用药记录').fontSize(12).fontColor('#777777')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('管理 ›').fontSize(14).fontColor('#0A84FF')
            }
            .width('100%')
            .onClick(() => this.onMaintainModules())
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('◉').fontSize(18).fontColor('#0A84FF')
              Text('成员资料').fontSize(16).fontWeight(FontWeight.Medium)
            }.width('100%')
            this.infoRow('亲属关系', MemberRelationshipCatalog.displayTitle(this.member?.relationship ?? 'other'))
            this.infoRow('性别', this.genderTitle())
            this.infoRow('出生日期', this.member?.birthDate ?? '')
            this.infoRow('血型', this.member?.bloodType ?? '')
            this.infoRow('过敏史', this.member?.allergies.join('、') ?? '')
            this.infoRow('慢性病', this.member?.chronicConditions.join('、') ?? '')
            this.infoRow('备注', this.member?.notes ?? '')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('♧').fontSize(18).fontColor('#0A84FF')
              Text('共享与权限').fontSize(16).fontWeight(FontWeight.Medium)
            }.width('100%')
            this.infoRow('当前角色', this.member?.effectiveBinding.role ?? '未知')
            this.infoRow('共享成员', `${this.member?.effectiveBinding.sharedUserCount ?? 0} 人`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          if (this.member?.effectiveBinding.canDelete || this.member?.effectiveBinding.canUnbind) {
            Button(this.isDeleting ? '处理中…' : this.deleteTitle())
              .width('100%')
              .height(48)
              .enabled(!this.isDeleting)
              .fontColor('#FF3B30')
              .backgroundColor('#FFF1F0')
              .borderRadius(14)
              .onClick(() => this.confirmDelete())
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F8')
  }
}
