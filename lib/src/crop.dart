part of crop;

/// Used for cropping the [child] widget.
class Crop extends StatefulWidget {
  /// The constructor.
  const Crop({
    Key? key,
    required this.child,
    required this.controller,
    this.padding = const EdgeInsets.all(8),
    this.dimColor = const Color.fromRGBO(0, 0, 0, 0.8),
    this.backgroundColor = Colors.black,
    this.background,
    this.foreground,
    this.helper,
    this.overlay,
    this.interactive = true,
    this.shape = BoxShape.rectangle,
    this.onChanged,
    this.animationDuration = const Duration(milliseconds: 200),
    this.radius,
    this.scaleLimit,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// Controls the crop area.
  final CropController controller;

  /// Background color of the crop area.
  final Color backgroundColor;

  /// Dim color of the crop area.
  final Color dimColor;

  /// Padding of the crop area.
  final EdgeInsets padding;

  /// Background widget displayed on under on the resulting image.
  final Widget? background;

  /// Forground widget is displayed on top on the resulting image.
  final Widget? foreground;

  /// Helper widget is displayed on top on the crop
  /// area, but not included in the resulting image.
  ///
  /// Useful to display helper lines e.g. golden ratio.
  final Widget? helper;

  /// Similar to [helper] but is not transformed.
  final Widget? overlay;

  /// If set to false, the widget will not listen for gestures.
  final bool interactive;

  /// Shape of the crop area.
  final BoxShape shape;

  /// Triggered when a gesture is detected.
  final ValueChanged<MatrixDecomposition>? onChanged;

  /// When dragged out of crop area boundries, it will
  /// re-center. This sets the re-center duration.
  final Duration animationDuration;

  /// Radius of the crop area.
  final Radius? radius;

  /// Maximum zoom scale
  final double? scaleLimit;

  @override
  State<StatefulWidget> createState() {
    return _CropState();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
    properties.add(ColorProperty('dimColor', dimColor));
    properties.add(DiagnosticsProperty('child', child));
    properties.add(DiagnosticsProperty('controller', controller));
    properties.add(DiagnosticsProperty('background', background));
    properties.add(DiagnosticsProperty('foreground', foreground));
    properties.add(DiagnosticsProperty('helper', helper));
    properties.add(DiagnosticsProperty('overlay', overlay));
    properties.add(FlagProperty(
      'interactive',
      value: interactive,
      ifTrue: 'enabled',
      ifFalse: 'disabled',
      showName: true,
    ));
  }
}

class _CropState extends State<Crop> with TickerProviderStateMixin {
  final _key = GlobalKey();
  final _parent = GlobalKey();
  final _repaintBoundaryKey = GlobalKey();
  final _childKey = GlobalKey();

  double _previousScale = 1;
  Offset _previousOffset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _endOffset = Offset.zero;

  /// Store the pointer count (finger involved to perform scaling).
  ///
  /// This is used to compare with the value in
  /// [ScaleUpdateDetails.pointerCount]. Check [_onScaleUpdate] for detail.

  late AnimationController _controller;
  late CurvedAnimation _animation;

  Future<ui.Image> _crop(double pixelRatio) {
    final rrb = _repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary;
    return rrb.toImage(pixelRatio: pixelRatio);
  }

  @override
  void initState() {
    widget.controller._cropCallback = _crop;
    widget.controller.addListener(_reCenterImage);

    //Setup animation.
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = CurvedAnimation(curve: Curves.easeInOut, parent: _controller);
    _animation.addListener(() {
      if (_animation.isCompleted) {
        _reCenterImage(false);
      }
      setState(() {});
    });
    super.initState();
  }

  void _reCenterImage([bool animate = true]) {
    final widgetSize = _key.currentContext!.size!;
    final childBox =
        (_childKey.currentContext?.findRenderObject() as RenderBox);
    final childXform = childBox.getTransformTo(null);
    final viewScale = childXform.row0[0];
    final imageDimensions = childBox.paintBounds;
    final imageScreenSize = Size(
        imageDimensions.width * viewScale, imageDimensions.height * viewScale);

    final maxDx = max(0.0, imageScreenSize.width - widgetSize.width) / 2;
    final maxDy = max(0.0, imageScreenSize.height - widgetSize.height) / 2;

    _startOffset = widget.controller._offset;
    widget.controller._offset = _endOffset = Offset(
        _startOffset.dx.clamp(-maxDx, maxDx),
        _startOffset.dy.clamp(-maxDy, maxDy));

    if (animate) {
      if (_controller.isCompleted || _controller.isAnimating) {
        _controller.reset();
      }
      _controller.forward();
    } else {
      _startOffset = _endOffset;
    }

    setState(() {});
    _handleOnChanged();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    widget.controller._offset += details.focalPoint - _previousOffset;
    _previousOffset = details.focalPoint;
    widget.controller._scale = _previousScale * details.scale;
    if (widget.scaleLimit != null &&
        widget.controller._scale > widget.scaleLimit!) {
      widget.controller._scale = widget.scaleLimit!;
    }
    _startOffset = widget.controller._offset;
    _endOffset = widget.controller._offset;

    setState(() {});
    _handleOnChanged();
  }

  void _handleOnChanged() {
    widget.onChanged?.call(MatrixDecomposition(
        scale: widget.controller.scale,
        rotation: 0,
        translation: widget.controller._offset));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller._scale;
    final o = Offset.lerp(_startOffset, _endOffset, _animation.value)!;

    Widget buildInnerCanvas() {
      final ip = IgnorePointer(
        key: _key,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(o.dx, o.dy, 0)
            ..scale(s, s, 1),
          child: FittedBox(
            fit: BoxFit.cover,
            child: Container(key: _childKey, child: widget.child),
          ),
        ),
      );

      List<Widget> widgets = [];

      if (widget.background != null) {
        widgets.add(widget.background!);
      }

      widgets.add(ip);

      if (widget.foreground != null) {
        widgets.add(widget.foreground!);
      }

      if (widgets.length == 1) {
        return ip;
      } else {
        return Stack(
          fit: StackFit.expand,
          children: widgets,
        );
      }
    }

    Widget buildRepaintBoundary() {
      final repaint = RepaintBoundary(
        key: _repaintBoundaryKey,
        child: buildInnerCanvas(),
      );

      final helper = widget.helper;

      if (helper == null) {
        return repaint;
      }

      return Stack(
        fit: StackFit.expand,
        children: [repaint, helper],
      );
    }

    final gd = GestureDetector(
      onScaleStart: (details) {
        _previousOffset = details.focalPoint;
        _previousScale = max(widget.controller._scale, 1);
      },
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: (details) {
        widget.controller._scale = max(widget.controller._scale, 1);
        _reCenterImage();
      },
    );

    List<Widget> over = [
      CropRenderObjectWidget(
        aspectRatio: widget.controller._aspectRatio,
        backgroundColor: widget.backgroundColor,
        shape: widget.shape,
        dimColor: widget.dimColor,
        padding: widget.padding,
        radius: widget.radius,
        child: buildRepaintBoundary(),
      ),
    ];

    if (widget.overlay != null) {
      over.add(widget.overlay!);
    }

    if (widget.interactive) {
      over.add(gd);
    }

    return ClipRect(
      key: _parent,
      child: Stack(
        fit: StackFit.expand,
        children: over,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.controller.removeListener(_reCenterImage);
    super.dispose();
  }
}
