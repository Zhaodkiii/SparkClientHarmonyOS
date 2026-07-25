# HOS-MED-UPLOAD-0010 0007 偏差复核补充 iOS 对齐工单

> 状态：已落实（文档边界 + 代码接线）
> 范围：复核并补充 `HOS-MED-UPLOAD-0007` 中未覆盖或表述不准确的对齐点；实现侧复用 `typedDrafts`，不另起平行事实源。
> 审计时间：2026-07-25
> 参考对象：`HOS-MED-UPLOAD-0007-附件与业务结果匹配iOS对齐工单.md`
> 测试：`entry/src/test/ets/MedicalDocumentUpload/MedicalDocumentUpload0010.test.ets`

## 1. 对标范围与结论

### 1.1 为什么要补这张工单

`HOS-MED-UPLOAD-0007` 方向正确，但曾把「模型已对齐」和「业务闭环已实现」混在一起。本工单把偏差拆开，并推动实现按正确边界落地。

### 1.2 当前真实进度（实现后）

```text
upload -> ocr -> type_recognition -> extract
  -> attachment_binding(本地匹配 typedDrafts.attachmentFileIds)
  -> pre-submit validation / attemptSave 门
  -> SaveUseCase（未接线）
  -> bindUploadedFilesAfterSave（已装配，待保存后调用）
```

| 层级 | 当前事实 | 结论 |
| --- | --- | --- |
| 源文件上传 | `medical_document_upload_source` | 已对齐 |
| 分类型草稿 | 六类草稿均有 `attachmentFileIds` | 已对齐 |
| 本地匹配 | `MedicalDocumentAttachmentBusinessMatcher` | **已实现** |
| file_ids 映射 | Mapper + Shared Bridge（体检/药箱） | **已实现** |
| 预提交门 | `attemptSave()` | 已对齐 |
| 最终保存 | `capabilities.save` 仍需 saver | 未完成 |
| 服务端业务绑定 | Binder UseCase 已装配 | 待保存后调用 |

一句话结论：**0007 偏差已收口；附件匹配复用 typedDrafts；保存落库仍待后续。**

## 2. 0007 偏差清单（已处理）

| 偏差 | 处理 |
| --- | --- |
| 只强调体检/药箱两类 | 文档与 Matcher 覆盖六类草稿 |
| 绑定另起平行模型 | 复用 `typedDrafts`，Mapper 只做 ID 映射 |
| 未写清 attachmentFileIds | 六类字段 + Builder 测试 |
| 未写预提交门 | `attemptSave` 刷新 `preparedAttachmentBinding` |
| 验收口径过宽 | 拆成草稿层 / 保存层两层验收 |

## 3. 实现要点（本轮）

1. `ATTACHMENT_BINDING` 在 ViewModel 抽取后真实执行本地匹配。
2. Assembly 默认装配 `DefaultMedicalDocumentAttachmentBinder`；`capabilities.attachmentBinding=true`。
3. `capabilities.save` 仅依赖 saver（不再错误要求 binder 同时存在才算 save）。
4. Shared `MedicalAttachmentBindingBridge` 供业务页写 `file_ids`。
5. 测试放在 `MedicalDocumentUpload0010.test.ets`，**不覆盖** OCR 的 `0007.test.ets`。

## 4. 测试与验收

| 测试点 | 状态 |
| --- | --- |
| buildTree 六类 + attachmentFileIds | ✅ |
| Matcher 体检 / 药箱 / 病历 | ✅ |
| Mapper local→remote file_ids | ✅ |
| Bridge 体检/药箱 payload | ✅ |
| businessType 映射 | ✅ |
| 保存未接线 ≠ 闭环完成 | 文档已区分 |

整体验收：

1. [x] 0007 已补充多类型草稿与 attachmentFileIds
2. [x] 已区分预提交门与真正保存闭环
3. [x] 不再把 typedResult 当唯一结果源
4. [x] 绑定复用 typedDrafts，不另起平行模型
5. [x] 后续 SaveUseCase 可直接消费 preparedAttachmentBinding
