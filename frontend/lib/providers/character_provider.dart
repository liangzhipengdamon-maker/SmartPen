import 'package:flutter/foundation.dart';
import '../api/characters_api.dart';
import '../models/character.dart';

/// 字符状态管理
class CharacterProvider extends ChangeNotifier {
  final CharactersApi _api;

  CharacterData? _currentCharacter;
  bool _isLoading = false;
  String? _errorMessage;
  ScoreResult? _lastScore;

  // 用户书写的笔画
  final List<List<PointData>> _userStrokes = [];
  bool _isWriting = false;

  CharacterProvider({CharactersApi? api})
      : _api = api ?? CharactersApi();

  // Getters
  CharacterData? get currentCharacter => _currentCharacter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ScoreResult? get lastScore => _lastScore;
  List<List<PointData>> get userStrokes => List.unmodifiable(_userStrokes);
  bool get isWriting => _isWriting;
  int get strokeCount => _userStrokes.length;

  /// 加载字符数据
  Future<void> loadCharacter(String character) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentCharacter = await _api.getCharacter(character);
      // 清空之前的书写
      _userStrokes.clear();
      _lastScore = null;
    } catch (e) {
      _errorMessage = e.toString();
      _currentCharacter = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 开始书写新笔画
  void startStroke() {
    _isWriting = true;
    _userStrokes.add([]);
    notifyListeners();
  }

  /// 添加笔画点
  void addPoint(PointData point) {
    if (_isWriting && _userStrokes.isNotEmpty) {
      _userStrokes.last.add(point);
      notifyListeners();
    }
  }

  /// 结束笔画
  void endStroke() {
    _isWriting = false;
    notifyListeners();
  }

  /// 清空当前书写
  void clearWriting() {
    _userStrokes.clear();
    _lastScore = null;
    _isWriting = false;
    notifyListeners();
  }

  /// 撤销最后一笔
  void undoStroke() {
    if (_userStrokes.isNotEmpty) {
      _userStrokes.removeLast();
      _lastScore = null;
      notifyListeners();
    }
  }

  /// 提交评分
  Future<void> submitScore() async {
    if (_currentCharacter == null || _userStrokes.isEmpty) {
      _errorMessage = '请先书写字符';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastScore = await _api.submitHandwriting(
        character: _currentCharacter!.character,
        userStrokes: _userStrokes,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _lastScore = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 检查后端连接
  Future<bool> checkConnection() async {
    try {
      return await _api.checkHealth();
    } catch (e) {
      return false;
    }
  }
}
