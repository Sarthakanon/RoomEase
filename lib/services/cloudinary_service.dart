import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../core/constants.dart';

class CloudinaryService {
  final Dio _dio = Dio();

  Future<String> uploadQrImage(File file) async {
    final uploadUrl =
        'https://api.cloudinary.com/v1_1/${AppConstants.cloudinaryCloudName}/image/upload';

    final formData = FormData.fromMap({
      'upload_preset': AppConstants.cloudinaryUploadPreset,
      'folder': AppConstants.cloudinaryFolder,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: path.basename(file.path),
      ),
    });

    final response = await _dio.post(uploadUrl, data: formData);
    final data = response.data as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary upload failed');
    }
    return secureUrl;
  }
}
