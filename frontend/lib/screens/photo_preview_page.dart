import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/character.dart';
import 'score_page.dart';

class PhotoPreviewPage extends StatefulWidget {
  final XFile photo;
  final CharacterData? character;

  const PhotoPreviewPage({
    super.key,
    required this.photo,
    this.character,
  });

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  XFile? _currentPhoto;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  String? _originalSavedPath;
  final CropController _cropController = CropController();

  @override
  void initState() {
    super.initState();
    _saveOriginal();
  }

  Future<Directory> _ensurePhotoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'SmartPen', 'photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _timestampName(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$ts.jpg';
  }

  Future<String> _saveCopy(String sourcePath, String prefix) async {
    final dir = await _ensurePhotoDir();
    final target = p.join(dir.path, _timestampName(prefix));
    await File(sourcePath).copy(target);
    return target;
  }

  Future<void> _saveOriginal() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final savedPath = await _saveCopy(widget.photo.path, 'photo');
      if (!mounted) return;
      _originalSavedPath = savedPath;
      final bytes = await File(savedPath).readAsBytes();
      setState(() {
        _currentPhoto = XFile(savedPath);
        _imageBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存原图失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
        final fallback = widget.photo;
        final bytes = await File(fallback.path).readAsBytes();
        setState(() {
          _currentPhoto = fallback;
          _imageBytes = bytes;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _cropPhoto() {
    if (_imageBytes == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });
    _cropController.crop();
  }

  void _goToScore() {
    final photo = _currentPhoto ?? widget.photo;
    final character = widget.character;
    if (character == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('范字未加载，暂无法评分，请稍后重试'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScorePage(
          photo: photo,
          character: character,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('照片预览'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _imageBytes == null
                  ? const CircularProgressIndicator()
                  : Crop(
                      image: _imageBytes!,
                      controller: _cropController,
                      onCropped: (data) async {
                        try {
                          final dir = await _ensurePhotoDir();
                          final path = p.join(dir.path, _timestampName('crop'));
                          await File(path).writeAsBytes(data);
                          if (!mounted) return;
                          setState(() {
                            _currentPhoto = XFile(path);
                            _imageBytes = data;
                          });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('裁剪失败: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                            });
                          }
                        }
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_originalSavedPath != null)
                    Text(
                      '原图已保存',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _cropPhoto,
                          icon: const Icon(Icons.crop),
                          label: Text(_isProcessing ? '处理中...' : '裁剪'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isProcessing || widget.character == null ? null : _goToScore,
                          icon: const Icon(Icons.check),
                          label: const Text('开始评分'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.character == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '范字未加载，裁剪后请返回重试',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
