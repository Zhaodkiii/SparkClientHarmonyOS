import { promptAction } from '@kit.ArkUI';
import { Member } from '../../../../Core/Domain/Entities/Member';
import { ManageHomeMemberUseCase } from '../../Application/ManageHomeMemberUseCase';
import { MemberRelationshipCatalog } from './MemberRelationshipCatalog';

export type MemberEditorMode = 'create' | 'edit';

/**
 * 成员新增/编辑表单。与 iOS AddFamilyMemberView 的可见字段和保存门槛对齐。
 */
@Component
export struct MemberEditorPage {
  mode: MemberEditorMode = 'create';
  member?: Member;
  memberUseCase?: ManageHomeMemberUseCase;
  onClose: () => void = () => {};
  onSaved: (member: Member) => void = (_member: Member) => {};

  @State private name: string = '';
  @State private relationshipCode: string = MemberRelationshipCatalog.DEFAULT_CODE;
  @State private gender: string = MemberRelationshipCatalog.UNSET_GENDER;
  @State private birthDate: string = '';
  @State private isSaving: boolean = false;
  @State private relationshipCodes: string[] = MemberRelationshipCatalog.flatCodes();

  aboutToAppear(): void {
    const member = this.member;
    if (this.mode === 'edit' && member) {
      this.name = member.name;
      this.relationshipCode = MemberRelationshipCatalog.compatibleCode(member.relationship);
      this.gender = MemberRelationshipCatalog.isSelectableGender(member.gender) ? member.gender.toLowerCase() : '';
      this.birthDate = member.birthDate ?? '';
    }
  }

  private canSave(): boolean {
    return this.name.trim().length > 0
      && this.birthDate.trim().length > 0
      && MemberRelationshipCatalog.isSelectableGender(this.gender)
      && !this.isSaving;
  }

  private isValidBirthDate(): boolean {
    return /^\d{4}-\d{2}-\d{2}$/.test(this.birthDate.trim());
  }

  private selectRelationship(code: string): void {
    this.relationshipCode = code;
    const inferred = MemberRelationshipCatalog.option(code).inferredGender;
    if (inferred && inferred.length > 0) {
      this.gender = inferred;
    } else if (code === 'self' || code === 'other') {
      this.gender = '';
    }
  }

  private async save(): Promise<void> {
    const useCase = this.memberUseCase;
    if (!useCase || !this.canSave()) {
      return;
    }
    if (!this.isValidBirthDate()) {
      promptAction.showToast({ message: '出生日期请使用 YYYY-MM-DD 格式', duration: 2500 });
      return;
    }
    this.isSaving = true;
    try {
      let saved: Member;
      if (this.mode === 'edit' && this.member) {
        saved = await useCase.update(
          this.member,
          this.name.trim(),
          this.relationshipCode,
          this.gender,
          this.birthDate.trim()
        );
      } else {
        saved = await useCase.create(
          this.name.trim(),
          this.relationshipCode,
          this.gender,
          this.birthDate.trim()
        );
      }
      this.onSaved(saved);
    } catch (e) {
      promptAction.showToast({ message: `保存成员失败：${e}`, duration: 2500 });
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  header() {
    Row() {
      Text('取消')
        .fontSize(15)
        .fontColor('#0A84FF')
        .width(48)
        .onClick(() => this.onClose())
      Text(this.mode === 'create' ? '添加成员' : '编辑成员')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
      Text(this.isSaving ? '保存中' : '保存')
        .fontSize(15)
        .fontColor(this.canSave() ? '#0A84FF' : '#9BA0A6')
        .width(48)
        .textAlign(TextAlign.End)
        .onClick(() => this.save())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
  }

  @Builder
  fieldLabel(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor('#666666')
      .width('100%')
  }

  @Builder
  choiceChip(title: string, selected: boolean, onTap: () => void) {
    Text(title)
      .fontSize(14)
      .fontColor(selected ? Color.White : '#1C1C1E')
      .backgroundColor(selected ? '#0A84FF' : '#F2F2F7')
      .padding({ left: 13, right: 13, top: 8, bottom: 8 })
      .borderRadius(12)
      .onClick(onTap)
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column({ space: 18 }) {
          Text('健康记录、医疗资料和后续服务都会关联到该成员。')
            .fontSize(13)
            .fontColor('#6B7280')
            .width('100%')

          this.fieldLabel('亲属关系')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.relationshipCodes, (code: string) => {
              Text(MemberRelationshipCatalog.option(code).title)
                .fontSize(14)
                .fontColor(this.relationshipCode === code ? Color.White : '#1C1C1E')
                .backgroundColor(this.relationshipCode === code ? '#0A84FF' : '#F2F2F7')
                .padding({ left: 13, right: 13, top: 8, bottom: 8 })
                .borderRadius(12)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.selectRelationship(code))
            }, (code: string): string => code)
          }
          .width('100%')

          this.fieldLabel('姓名')
          TextInput({ text: this.name, placeholder: '请输入成员姓名' })
            .height(48)
            .backgroundColor('#F2F2F7')
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => this.name = value)

          this.fieldLabel('性别')
          Row({ space: 10 }) {
            this.choiceChip('男', this.gender === 'male', () => this.gender = 'male')
            this.choiceChip('女', this.gender === 'female', () => this.gender = 'female')
          }
          .width('100%')

          this.fieldLabel('出生日期')
          TextInput({ text: this.birthDate, placeholder: 'YYYY-MM-DD' })
            .height(48)
            .backgroundColor('#F2F2F7')
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => this.birthDate = value.trim())

          Button(this.isSaving ? '保存中…' : (this.mode === 'create' ? '添加成员' : '保存修改'))
            .width('100%')
            .height(48)
            .enabled(this.canSave())
            .backgroundColor(this.canSave() ? '#0A84FF' : '#C7C7CC')
            .fontColor(Color.White)
            .borderRadius(14)
            .margin({ top: 8 })
            .onClick(() => this.save())
        }
        .width('100%')
        .padding(20)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F8')
  }
}
