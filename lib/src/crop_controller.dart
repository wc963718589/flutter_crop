part of crop;

/// The controller used to control the scale and offset.
class CropController extends ChangeNotifier {
  /// Constructor
  CropController({
    double aspectRatio = 1.0,
    double scale = 1.0,
    bool flip = false
  }) {
    _aspectRatio = aspectRatio;
    _scale = scale;
    _flip = flip;
  }
  double _aspectRatio = 1;
  double _scale = 1;
  Offset _offset = Offset.zero;
  bool _flip = false;
  Future<ui.Image> Function(double pixelRatio)? _cropCallback;

  /// Gets the current aspect ratio.
  double get aspectRatio => _aspectRatio;

  /// Sets the desired aspect ratio.
  set aspectRatio(double value) {
    _aspectRatio = value;
    notifyListeners();
  }

  /// Gets the current scale.
  double get scale => max(_scale, 1);

  /// Sets the desired scale.
  set scale(double value) {
    _scale = max(value, 1);
    notifyListeners();
  }

  /// Gets the current flip.
  bool get flip => _flip;

  /// Sets the flip
  set flip(bool value) {
    _flip = value;
    notifyListeners();
  }

  /// toggle flip
  void toggleFlip() {
    _flip = !_flip;
    notifyListeners();
  }

  /// Gets the current offset.
  Offset get offset => _offset;

  /// Sets the desired offset.
  set offset(Offset value) {
    _offset = value;
    notifyListeners();
  }

  /// Gets the transformation matrix.
  Matrix4 get transform => Matrix4.identity()
    ..rotateY(_flip ? pi : 0)
    ..translate(_flip ? -_offset.dx : _offset.dx, _offset.dy, 0)
    ..scale(_scale, _scale, 1);

  /// Capture an image of the current state of this widget and its children.
  ///
  /// The returned [ui.Image] has uncompressed raw RGBA bytes, will have
  /// dimensions equal to the size of the [child] widget multiplied by [pixelRatio].
  ///
  /// The [pixelRatio] describes the scale between the logical pixels and the
  /// size of the output image. It is independent of the
  /// [window.devicePixelRatio] for the device, so specifying 1.0 (the default)
  /// will give you a 1:1 mapping between logical pixels and the output pixels
  /// in the image.
  Future<ui.Image?> crop({double pixelRatio = 1}) {
    if (_cropCallback == null) {
      return Future.value(null);
    }

    return _cropCallback!.call(pixelRatio);
  }
}
