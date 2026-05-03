import 'package:flutter/material.dart';

class FileStyle {
  final IconData icon;
  final Color color;
  final String ext;
  const FileStyle(this.icon, this.color, this.ext);
}

FileStyle fileStyleFor(String name, bool isDir) {
  if (isDir) return const FileStyle(Icons.folder_rounded, Color(0xFF58A6FF), '');
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'dart':
      return FileStyle(Icons.code_rounded, const Color(0xFF54C5F8), ext);
    case 'py':
      return FileStyle(Icons.code_rounded, const Color(0xFFFFD43B), ext);
    case 'js':
      return FileStyle(Icons.javascript_rounded, const Color(0xFFF7DF1E), ext);
    case 'ts':
      return FileStyle(Icons.code_rounded, const Color(0xFF3178C6), ext);
    case 'json':
      return FileStyle(Icons.data_object_rounded, const Color(0xFFFF9500), ext);
    case 'yaml':
    case 'yml':
      return FileStyle(Icons.settings_rounded, const Color(0xFFFF6B6B), ext);
    case 'md':
    case 'mdx':
      return FileStyle(Icons.article_rounded, const Color(0xFFBB8EF8), ext);
    case 'html':
      return FileStyle(Icons.html_rounded, const Color(0xFFE34C26), ext);
    case 'css':
    case 'scss':
    case 'sass':
      return FileStyle(Icons.style_rounded, const Color(0xFF264DE4), ext);
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return FileStyle(Icons.image_rounded, const Color(0xFF4CAF50), ext);
    case 'go':
      return FileStyle(Icons.code_rounded, const Color(0xFF00ACD7), ext);
    case 'rs':
      return FileStyle(Icons.code_rounded, const Color(0xFFCE412B), ext);
    case 'sh':
    case 'bash':
    case 'zsh':
      return FileStyle(Icons.terminal_rounded, const Color(0xFF4EAA25), ext);
    case 'sql':
      return FileStyle(Icons.storage_rounded, const Color(0xFF00758F), ext);
    case 'txt':
      return FileStyle(Icons.text_snippet_rounded, const Color(0xFF8B949E), ext);
    case 'pdf':
      return FileStyle(Icons.picture_as_pdf_rounded, const Color(0xFFFF5252), ext);
    case 'lock':
      return FileStyle(Icons.lock_rounded, const Color(0xFF8B949E), ext);
    case 'env':
      return FileStyle(Icons.key_rounded, const Color(0xFFFFAB40), ext);
    case 'toml':
      return FileStyle(Icons.settings_rounded, const Color(0xFFFF6B35), ext);
    case 'gradle':
    case 'xml':
      return FileStyle(Icons.code_rounded, const Color(0xFF77BD43), ext);
    case 'kt':
    case 'kts':
      return FileStyle(Icons.code_rounded, const Color(0xFF7F52FF), ext);
    case 'java':
      return FileStyle(Icons.code_rounded, const Color(0xFFED8B00), ext);
    case 'swift':
      return FileStyle(Icons.code_rounded, const Color(0xFFFF5F57), ext);
    case 'cpp':
    case 'c':
    case 'h':
      return FileStyle(Icons.code_rounded, const Color(0xFF00599C), ext);
    case 'rb':
      return FileStyle(Icons.code_rounded, const Color(0xFFCC342D), ext);
    case 'php':
      return FileStyle(Icons.code_rounded, const Color(0xFF8993BE), ext);
    case 'gitignore':
    case 'gitattributes':
      return FileStyle(Icons.merge_type_rounded, const Color(0xFFF05033), ext);
    default:
      return FileStyle(Icons.insert_drive_file_outlined, const Color(0xFF8B949E), ext);
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
