import { MedicalPreSubmitValidationIssue } from '../../../Domain/MedicalPreSubmitValidationIssue';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

/**
 * 预提交校验定位：展开折叠分区并滚动提示。对齐 iOS MedicalPreSubmitValidationNavigation。
 */
export class MedicalPreSubmitValidationNavigation {
  static reveal(
    viewModel: MedicalDocumentUploadViewModel,
    issueIndex: number,
    scroller?: Scroller
  ): void {
    const issues = viewModel.preSubmitIssues();
    if (issueIndex < 0 || issueIndex >= issues.length) {
      return;
    }
    MedicalPreSubmitValidationNavigation.revealIssue(viewModel, issues[issueIndex], scroller);
  }

  static revealIssue(
    viewModel: MedicalDocumentUploadViewModel,
    issue: MedicalPreSubmitValidationIssue,
    scroller?: Scroller
  ): void {
    const section = issue.collapseSectionID();
    if (section !== undefined) {
      viewModel.expandPreSubmitSection(section);
    }
    if (scroller !== undefined) {
      scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    }
  }
}
