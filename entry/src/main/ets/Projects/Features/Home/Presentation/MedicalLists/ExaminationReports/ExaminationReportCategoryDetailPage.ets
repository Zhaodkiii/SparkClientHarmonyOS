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
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor('#0A84FF')
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })
        Blank()
        Text(this.titleText())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

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
    .backgroundColor('#F2F2F7')
  }
}
