import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../services/ai_verifier.dart';
import '../services/photo_service.dart';
import '../services/validators.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import 'passport_photo.dart';

/// Hộp thoại cho tác giả sửa nội dung/ảnh bài cảm nhận và tự động kích hoạt
/// chấm lại điểm AI qua Cloud Function `verifyReflection`.
Future<void> showEditReflectionDialog(
  BuildContext context,
  Reflection reflection,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditReflectionDialog(reflection: reflection),
  );
}

class _EditReflectionDialog extends StatefulWidget {
  const _EditReflectionDialog({required this.reflection});

  final Reflection reflection;

  @override
  State<_EditReflectionDialog> createState() => _EditReflectionDialogState();
}

class _EditReflectionDialogState extends State<_EditReflectionDialog> {
  late final _controller = TextEditingController(
    text: widget.reflection.content,
  );
  Uint8List? _newPhotoBytes;
  bool _removedExistingPhoto = false;
  bool _saving = false;
  String? _error;

  bool get _hasAnyPhoto =>
      _newPhotoBytes != null ||
      (!_removedExistingPhoto && widget.reflection.hasPhoto);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPhotoBytes = bytes;
        _removedExistingPhoto = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đọc được ảnh mới.');
      }
    }
  }

  Future<void> _save() async {
    final store = PassportScope.read(context);
    final location = locationById[widget.reflection.locationId];
    if (location == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    String? compressedBase64;
    final effectivePhotoUrl = _removedExistingPhoto || _newPhotoBytes != null
        ? null
        : widget.reflection.photoUrl;

    if (_newPhotoBytes != null) {
      try {
        compressedBase64 = await compressImageToBase64(_newPhotoBytes!);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
        return;
      }
    }

    try {
      final result = await verifyReflection(
        content: _controller.text,
        hasPhoto: _hasAnyPhoto,
        location: location,
        reflectionId: widget.reflection.id,
        displayAuthor: widget.reflection.displayAuthor,
        isAnonymous: widget.reflection.isAnonymous,
        photoUrl: effectivePhotoUrl,
      );
      if (!mounted) return;
      if (!result.approved) {
        setState(() {
          _saving = false;
          _error = result.comment;
        });
        return;
      }

      store.updateReflection(
        id: widget.reflection.id,
        content: _controller.text.trim(),
        photoUrl: effectivePhotoUrl,
        photoBase64: compressedBase64,
        clearPhoto: _removedExistingPhoto && _newPhotoBytes == null,
        aiScore: result.score,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật bài cảm nhận · Điểm mới: ${result.score}/100.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationError = validateReflection(_controller.text);
    return AlertDialog(
      title: Text('Sửa cảm nhận', style: displayStyle(22)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                enabled: !_saving,
                minLines: 4,
                maxLines: 6,
                maxLength: reflectionMaxLength,
                style: bodyStyle(14, height: 1.5),
                decoration: InputDecoration(
                  helperText:
                      validationError ??
                      'Sau khi lưu, AI sẽ tự động chấm lại điểm cho bài viết.',
                  helperMaxLines: 2,
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_newPhotoBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _newPhotoBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IconButton.filled(
                        tooltip: 'Bỏ ảnh mới',
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _newPhotoBytes = null;
                                _removedExistingPhoto = true;
                              }),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                )
              else if (!_removedExistingPhoto && widget.reflection.hasPhoto)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PassportPhoto(
                        photoUrl: widget.reflection.photoUrl,
                        photoBase64: widget.reflection.photoBase64,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IconButton.filled(
                        tooltip: 'Xóa ảnh',
                        onPressed: _saving
                            ? null
                            : () =>
                                  setState(() => _removedExistingPhoto = true),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_hasAnyPhoto ? 'Đổi ảnh' : 'Thêm ảnh'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: bodyStyle(13, color: const Color(0xFFB91C1C)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving || validationError != null ? null : _save,
          child: Text(_saving ? 'Đang chấm lại…' : 'Lưu & chấm lại'),
        ),
      ],
    );
  }
}
