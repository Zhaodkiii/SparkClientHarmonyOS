import { HomeViewModel } from '../../HomeViewModel';
import {
  examinationCategoryTitle
} from './ExaminationReportCategory';
import {
  ExaminationReportDetailSupport,
  ExaminationSubitemDetailTarget
} from './ExaminationReportDetailSupport';
import { ImagingReportDetailPage } from './ImagingReportDetailPage';
import { LaboratoryReportDetailPage } from './LaboratoryReportDetailPage';
import { PathologyReportDetailPage } from './PathologyReportDetailPage';
import { MEDICAL_LIST_PAGE_BG, MedicalDetailPageHeaderChrome } from '../Shared/MedicalListPageChrome';

/**
 * 检查报告分类明细路由页。对齐 iOS `ExaminationReportCategoryDetailPage`：
 * laboratory/imaging → ImagingReportDetailPage；pathology → PathologyReportDetailPage；
 * isFullLabTable → LaboratoryReportDetailPage。
 */
@Component
export struct ExaminationReportCategoryDetailPage {
  homeVm?: HomeViewModel;
  @Prop subitemTarget: ExaminationSubitemDetailTarget = new ExaminationSubitemDetailTarget();
  @Prop useLocalTarget: boolean = false;
  onBack?: () => void;

  private activeTarget(): ExaminationSubitemDetailTarget | undefined {
    if (this.useLocalTarget) {
      return this.subitemTarget;
    }
    return this.homeVm?.examinationSubitemDetailTarget;
  }

  private titleText(): string {
    const target = this.activeTarget();
    if (!target) {
      return '检查明细';
    }
    if (target.isFullLabTable) {
      return ExaminationReportDetailSupport.resolveNavigationTitle(
        target.navigationTitleOverride,
        target.report,
        '检验明细'
      );
    }
    if (target.category === 'pathology') {
      return ExaminationReportDetailSupport.resolveNavigationTitle(
        target.navigationTitleOverride,
        target.report,
        examinationCategoryTitle('pathology')
      );
    }
    return ExaminationReportDetailSupport.resolveNavigationTitle(
      target.navigationTitleOverride,
      target.report,
      examinationCategoryTitle('imaging')
    );
  }

  build() {
    Column() {
      MedicalDetailPageHeaderChrome({
        title: this.titleText(),
        onBack: () => {
          if (this.onBack) {
            this.onBack();
          }
        },
        showDivider: false
      })

      Scroll() {
        Column({ space: 12 }) {
          if (this.activeTarget() === undefined) {
            Text('未找到明细数据')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%')
              .padding(24)
              .textAlign(TextAlign.Center)
          } else if (this.activeTarget()!.isFullLabTable) {
            LaboratoryReportDetailPage({
              report: this.activeTarget()!.report,
              navigationTitleOverride: this.activeTarget()!.navigationTitleOverride
            })
          } else if (this.activeTarget()!.category === 'pathology') {
            PathologyReportDetailPage({
              report: this.activeTarget()!.report,
              navigationTitleOverride: this.activeTarget()!.navigationTitleOverride
            })
          } else {
            ImagingReportDetailPage({
              report: this.activeTarget()!.report,
              navigationTitleOverride: this.activeTarget()!.navigationTitleOverride
            })
          }
          Blank().height(24)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
  }
}
