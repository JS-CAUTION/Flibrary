import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../services/database_service.dart';
import '../widgets/diffuse_background.dart';

/// 导课 — Import Screen
/// Supports XLS file import with preview before confirming.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<Course>? _previewCourses;
  String? _semesterInfo;
  String? _errorMessage;
  bool _importing = false;

  Future<void> _pickAndParseFile() async {
    setState(() {
      _errorMessage = null;
      _previewCourses = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
        withData: true, // Read bytes directly (works on web too)
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        setState(() {
          _errorMessage = '无法读取文件内容';
        });
        return;
      }

      // Parse XLS from bytes
      final bytes = file.bytes!;
      final courses = StorageService.parseXlsFromBytes(bytes);
      final semester = StorageService.parseSemesterInfo(bytes);

      if (courses.isEmpty) {
        setState(() {
          _errorMessage = '未识别到课程数据，请确认文件格式正确';
        });
        return;
      }

      setState(() {
        _previewCourses = courses;
        _semesterInfo = semester;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败：$e';
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_previewCourses == null || _previewCourses!.isEmpty) return;

    setState(() => _importing = true);

    try {
      // Generate unique IDs for imported courses
      final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
      final courses = _previewCourses!.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;
        return c.copyWith(id: '${timestamp}_$index');
      }).toList();

      // Import new courses (don't clear old — caller decides)
      await context.read<CourseProvider>().importCourses(courses);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 ${courses.length} 门课程'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '导入失败：$e';
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: DiffuseBackground(
          child: SafeArea(
            child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.contentPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
                            const SizedBox(width: AppSpacing.md),
                            Text('导入课表', style: AppTypography.pageTitle),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Upload area
                      if (_previewCourses == null) ...[
                        _buildUploadArea(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildErrorCard(),
                        ],
                      ],

                      // Preview area
                      if (_previewCourses != null) ...[
                        _buildPreviewHeader(),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _previewCourses!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final c = _previewCourses![index];
                              return _CoursePreviewCard(
                                  course: c, index: index);
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildImportButton(),
                        const SizedBox(height: AppSpacing.sm),
                        _buildCancelPreviewButton(),
                      ],

                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Expanded(
      child: GestureDetector(
        onTap: _pickAndParseFile,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.formCard,
            border: Border.all(
                color: AppColors.divider,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.upload_file,
                    size: 36, color: AppColors.blue),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('上传课表 CSV 文件', style: AppTypography.bodySemiBold),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  '用 Excel 打开课表 .xls，另存为 .csv 再导入',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '选择文件',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_semesterInfo != null)
          Text(_semesterInfo!, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '识别到 ${_previewCourses!.length} 门课程，请确认后导入',
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: _importing ? null : _confirmImport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
        ),
        child: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('确认导入', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildCancelPreviewButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: TextButton(
        onPressed: () => setState(() {
          _previewCourses = null;
          _errorMessage = null;
        }),
        child: const Text('重新选择文件'),
      ),
    );
  }
}

class _CoursePreviewCard extends StatelessWidget {
  final Course course;
  final int index;

  const _CoursePreviewCard({required this.course, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.formCard,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: course.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: course.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name,
                    style: AppTypography.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${course.dayText} ${course.periodText} · ${course.weekText}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
