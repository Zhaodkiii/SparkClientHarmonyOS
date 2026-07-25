import { Member } from '../../../../../Core/Domain/Entities/Member';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalUploadL10n } from '../../../Domain/SupportingModels';

/**
 * 检查报告结果页成员选择器。对齐 iOS `MemberProfileBindingMenu`。
 */
@Component
export struct MedicalReportMemberBindingMenu {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop selectedMemberID: number = 0;
  onSelectMember?: (memberID: number) => void;

  @State private showPicker: boolean = false;

  private selectedName(): string {
    if (this.selectedMemberID > 0) {
      const name = this.viewModel.memberNameForID(this.selectedMemberID);
      if (name.length > 0) {
        return name;
      }
      return `${this.selectedMemberID}`;
    }
    if (this.viewModel.selectedMemberName.length > 0) {
      return this.viewModel.selectedMemberName;
    }
    return MedicalUploadL10n.text('medical.upload.member.not_selected');
  }

  private pickMember(member: Member): void {
    if (this.onSelectMember) {
      this.onSelectMember(member.id);
    } else {
      this.viewModel.updateResultMemberID(member.id);
    }
    this.showPicker = false;
  }

  @Builder
  private pickerSheet() {
    Column({ space: 12 }) {
      Text(MedicalUploadL10n.text('medical.upload.result.member.picker_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      ForEach(this.viewModel.members(), (member: Member) => {
        Row() {
          Text(member.name)
            .fontSize(15)
            .fontColor(member.id === this.selectedMemberID ? '#0A84FF' : '#1C1C1E')
            .layoutWeight(1)
          if (member.id === this.selectedMemberID) {
            Text(MedicalUploadL10n.text('medical.upload.result.member.current'))
              .fontSize(12)
              .fontColor('#0A84FF')
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .onClick(() => {
          this.pickMember(member);
        })
      }, (member: Member): string => `mr-member-${member.id}`)
    }
    .width('100%')
    .padding(20)
  }

  build() {
    Column({ space: 6 }) {
      Text(MedicalUploadL10n.text('medical.upload.result.member.title'))
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.person_badge_plus'))
          .fontSize(18)
          .fontColor(['#0A84FF'])
        Text(this.selectedName())
          .fontSize(15)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor(['#8E8E93'])
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#F2F2F7')
      .borderRadius(10)
      .border({ width: 1, color: '#E5E5EA' })
      .onClick(() => {
        this.showPicker = true;
      })
    }
    .width('100%')
    .bindSheet(this.showPicker, this.pickerSheet, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showPicker = false;
      }
    })
  }
}
