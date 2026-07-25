import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { MedicalReportRecognitionResultContentView } from './MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView';
import { MedicalReportRecognitionResultRoutes } from './MedicalReportRecognitionResult/MedicalReportRecognitionResultRoutes';
import { ExaminationReportCategory } from
  '../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';

/**
 * 检查报告识别结果入口。对齐 iOS `MedicalReportRecognitionResultView`：
 * 结果列表 + `NavigationLink` 式页面推入本地草稿详情。
 * 统一 Navigation 栈由 `MedicalDocumentUploadHostView` 持有（`viewModel.medicalUploadNavStack`），
 * 本视图只负责把卡片点击换算成 push，不再单独持有一层嵌套 Navigation，避免和宿主头部叠出双头部。
 */
@Component
export struct MedicalReportRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicalReportRecognitionResultContentView({
      viewModel: this.viewModel,
      onOpenCardDetail: (index: number, category: ExaminationReportCategory) => {
        this.viewModel.openMedicalReportCardDetail(index, category);
        this.viewModel.medicalUploadNavStack?.pushPath({
          name: MedicalReportRecognitionResultRoutes.LOCAL_DRAFT_DETAIL
        });
      }
    })
  }
}
