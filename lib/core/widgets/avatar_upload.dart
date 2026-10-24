// lib/core/widgets/avatar_upload.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AvatarUploadState { empty, preview, uploading, error }

class AvatarUpload extends StatelessWidget {
  final String? imageUrl;
  final AvatarUploadState state;
  final VoidCallback? onTap;
  final double size;

  const AvatarUpload({
    super.key,
    this.imageUrl,
    this.state = AvatarUploadState.empty,
    this.onTap,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state == AvatarUploadState.uploading ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: AppColors.gray200,
            backgroundImage: (state == AvatarUploadState.preview && imageUrl != null)
                ? NetworkImage(imageUrl!)
                : null,
            child: switch (state) {
              AvatarUploadState.empty => Icon(Icons.person, size: size * 0.5, color: AppColors.gray400),
              AvatarUploadState.error => const Icon(Icons.error_outline, color: AppColors.danger),
              _ => null,
            },
          ),
          if (state == AvatarUploadState.uploading)
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          const Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}