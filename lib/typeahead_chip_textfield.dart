import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class CustomTypeAheadChipTextField<T> extends StatefulWidget {
  final SuggestionsCallback<T> suggestionsCallback;
  final SuggestionSelectionCallback<T> onSuggestionSelected;
  final ItemBuilder<T> itemBuilder;

  final Color? hintColor;
  final String? hintText;
  final bool? isFilled;
  final List participantNameList;
  final String imageIcon;
  final Color? prefixIconColor;
  final String dropDownImageIcon;
  final Color? borderColor;
  final bool? isDeletable;
  final Widget Function(BuildContext, ChipsInputState, dynamic)?
      suggestionBuilder;
  final Widget Function(BuildContext, ChipsInputState, dynamic)? chipBuilder;
  final InputDecoration? inputDecoration;
  final EdgeInsets? suggestionBuilderPadding;
  final EdgeInsets? textFieldPadding;
  final List<T>? initialValue;
  final Widget? prefixIcon;
  final String? fontFamily;
  final Color? labelColor;
  final TextStyle? chipTextStyle;

  const CustomTypeAheadChipTextField(
      {Key? key,
      this.hintColor,
      this.hintText,
      this.isFilled,
      required this.suggestionsCallback,
      required this.onSuggestionSelected,
      required this.itemBuilder,
      required this.participantNameList,
      required this.imageIcon,
      required this.dropDownImageIcon,
      this.borderColor,
      this.isDeletable,
      this.suggestionBuilder,
      this.chipBuilder,
      this.inputDecoration,
      this.suggestionBuilderPadding,
      this.textFieldPadding,
      this.initialValue,
      this.prefixIcon,
      this.fontFamily,
      this.labelColor,
      this.prefixIconColor,
      this.chipTextStyle
      })
      : super(key: key);

  @override
  CustomTypeAheadChipTextFieldState<T> createState() =>
      CustomTypeAheadChipTextFieldState<T>();
}

class CustomTypeAheadChipTextFieldState<T> extends State<CustomTypeAheadChipTextField<T>> {
  @override
  Widget build(BuildContext context) {
    return ChipsInput<T>(
      itemBuilder: widget.itemBuilder,
      onSuggestionSelected: widget.onSuggestionSelected,
      suggestionsCallback: widget.suggestionsCallback,
      initialValue: widget.initialValue,
      decoration: widget.inputDecoration ??
          InputDecoration(
              isDense: true,
              contentPadding: widget.textFieldPadding ?? EdgeInsets.zero,
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                    width: 1, color: widget.borderColor ?? Colors.grey),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    width: 1, color: widget.borderColor ?? Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      width: 1, color: widget.borderColor ?? Colors.grey)),
              fillColor: Colors.white,
              filled: widget.isFilled ?? true,
              prefixIcon: widget.prefixIcon,
              labelStyle: TextStyle(
                fontSize: 12,
                color: widget.labelColor,
                fontFamily: widget.fontFamily,
              ),
              hintText: widget.hintText ?? '',
              hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: widget.fontFamily,
                  color:
                      widget.hintColor ?? Colors.grey)),
      onChanged: _onChanged,
      chipBuilder: widget.chipBuilder ??
          (BuildContext context, ChipsInputState<dynamic> state,
              dynamic value) {
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: Chip(
                deleteIconColor: (widget.isDeletable ?? false)
                    ? Colors.grey
                    : null,
                deleteIcon: (widget.isDeletable ?? false)
                    ? const Icon(Icons.highlight_remove)
                    : null,
                onDeleted: (widget.isDeletable ?? false)
                    ? () {
                        state.deleteChip(value);
                      }
                    : null,
                padding: EdgeInsets.zero,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                backgroundColor: Colors.white,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 1,
                shape:  const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(6),
                  ),
                  side: BorderSide(color: Colors.black12),
                ),
                label: Text(
                  value.name,
                  style: widget.chipTextStyle,
                ),
              ),
            );
          },
    );
  }

  void _onChanged(List data) {
    
  }
}

typedef ChipsInputSuggestions<T> = Future<List<T>> Function(String query);
typedef ChipSelected<T> = void Function(T data, bool selected);
typedef ChipsBuilder<T> = Widget Function(
    BuildContext context, ChipsInputState<T> state, T data);

class ChipsInput<T> extends StatefulWidget {
  const ChipsInput(
      {Key? key,
      this.initialValue,
      this.maxChips,
      this.decoration = const InputDecoration(),
      required this.chipBuilder,
      required this.onChanged,
      this.onChipTapped,
      required this.onSuggestionSelected,
      required this.itemBuilder,
      required this.suggestionsCallback})
      : assert(maxChips == null || (initialValue?.length ?? 0) <= maxChips),
        super(key: key);

  final InputDecoration decoration;
  final ValueChanged<List<T>> onChanged;
  final ValueChanged<T>? onChipTapped;
  final ChipsBuilder<T> chipBuilder;
  final int? maxChips;
  final List<T>? initialValue;

  final SuggestionsCallback<T> suggestionsCallback;
  final SuggestionSelectionCallback<T> onSuggestionSelected;
  final ItemBuilder<T> itemBuilder;

  @override
  ChipsInputState<T> createState() => ChipsInputState<T>();
}

class ChipsInputState<T> extends State<ChipsInput<T>>
    with WidgetsBindingObserver
    implements TextInputClient {
  static const kObjectReplacementChar = 0xFFFC;

  final LayerLink _layerLink = LayerLink();

  _MGChipSuggestionsBox? _suggestionsBox;

  final MGChipSuggestionsBoxController suggestionsBoxController =
      MGChipSuggestionsBoxController();
  SuggestionsBoxDecoration suggestionsBoxDecoration =
      const SuggestionsBoxDecoration();

  // Timer that resizes the suggestion box on each tick. Only active when the user is scrolling.
  Timer? _resizeOnScrollTimer;

  // The rate at which the suggestion box will resize when the user is scrolling
  final Duration _resizeOnScrollRefreshRate = const Duration(milliseconds: 500);

  // Will have a value if the typeahead is inside a scrollable widget
  ScrollPosition? _scrollPosition;

  TextEditingController textEditingController = TextEditingController();

  Set<T> _chips = <T>{};
  List<T>? _suggestions;
  int _searchId = 0;

  FocusNode? _focusNode;
  TextEditingValue _value = const TextEditingValue();
  TextInputConnection? _connection;

  String get text {
    return String.fromCharCodes(
      _value.text.codeUnits.where((ch) => ch != kObjectReplacementChar),
    );
  }

  @override
  TextEditingValue get currentTextEditingValue => _value;

  bool get _hasInputConnection => _connection != null && _connection!.attached;

  bool get _hasReachedMaxChips =>
      widget.maxChips != null && _chips.length >= widget.maxChips!;

  void requestKeyboard() {
    if (_focusNode!.hasFocus) {
      _openInputConnection();
    } else {
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void selectSuggestion(T data) {
    setState(() {
      _chips.add(data);
      _updateTextInputState();
      _suggestions = null;
    });
    widget.onChanged(_chips.toList(growable: false));
  }

  void deleteChip(T data) {
    setState(() {
      _chips.remove(data);
      _updateTextInputState();
    });
    widget.onChanged(_chips.toList(growable: false));
  }

  @override
  void initState() {
    super.initState();
    _chips.addAll(widget.initialValue ?? []);

    _focusNode = FocusNode();
    _focusNode!.addListener(_onFocusChanged);

    this._suggestionsBox =
        _MGChipSuggestionsBox(context, AxisDirection.down, false);
    suggestionsBoxController._suggestionsBox = this._suggestionsBox;
    suggestionsBoxController._effectiveFocusNode = _focusNode;

    WidgetsBinding.instance.addPostFrameCallback((duration) {
      if (mounted) {
        this._initOverlayEntry();
        // calculate initial suggestions list size
        this._suggestionsBox!.resize();

        // in case we already missed the focus event
        if (this._focusNode!.hasFocus) {
          this._suggestionsBox!.open();
        }
      }
    });
  }

  @override
  void didChangeMetrics() {
    // Catch keyboard event and orientation change; resize suggestions list
    this._suggestionsBox!.onChangeMetrics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ScrollableState? scrollableState = Scrollable.of(context);
    if (scrollableState != null) {
      // The MGTypeAheadTextField is inside a scrollable widget
      _scrollPosition = scrollableState.position;

      _scrollPosition!.removeListener(_scrollResizeListener);
      _scrollPosition!.isScrollingNotifier.addListener(_scrollResizeListener);
    }
  }

  void _scrollResizeListener() {
    bool isScrolling = _scrollPosition!.isScrollingNotifier.value;
    _resizeOnScrollTimer?.cancel();
    if (isScrolling) {
      // Scroll started
      _resizeOnScrollTimer =
          Timer.periodic(_resizeOnScrollRefreshRate, (timer) {
        _suggestionsBox!.resize();
      });
    } else {
      // Scroll finished
      _suggestionsBox!.resize();
    }
  }

  void _initOverlayEntry() {
    this._suggestionsBox!._overlayEntry = OverlayEntry(builder: (context) {
      final suggestionsList = _MGChipSuggestionsList<T>(
        suggestionsBox: _suggestionsBox,
        decoration: suggestionsBoxDecoration,
        controller: textEditingController,
        debounceDuration: const Duration(milliseconds: 300),
        suggestionsCallback: widget.suggestionsCallback,
        animationDuration: const Duration(milliseconds: 500),
        animationStart: 0.25,
        getImmediateSuggestions: false,
        onSuggestionSelected: (T selection) {
          this._focusNode!.unfocus();
          this._suggestionsBox!.close();
          this.selectSuggestion(selection);
          textEditingController.clear();
          widget.onSuggestionSelected(selection);
        },
        itemBuilder: widget.itemBuilder,
        direction: _suggestionsBox!.direction,
        hideOnLoading: false,
        hideOnEmpty: false,
        hideOnError: false,
        keepSuggestionsOnLoading: true,
        minCharsForSuggestions: 0,
      );

      double w = _suggestionsBox!.textBoxWidth;
      if (suggestionsBoxDecoration.constraints != null) {
        if (suggestionsBoxDecoration.constraints!.minWidth != 0.0 &&
            suggestionsBoxDecoration.constraints!.maxWidth != double.infinity) {
          w = (suggestionsBoxDecoration.constraints!.minWidth +
                  suggestionsBoxDecoration.constraints!.maxWidth) /
              2;
        } else if (suggestionsBoxDecoration.constraints!.minWidth != 0.0 &&
            suggestionsBoxDecoration.constraints!.minWidth > w) {
          w = suggestionsBoxDecoration.constraints!.minWidth;
        } else if (suggestionsBoxDecoration.constraints!.maxWidth !=
                double.infinity &&
            suggestionsBoxDecoration.constraints!.maxWidth < w) {
          w = suggestionsBoxDecoration.constraints!.maxWidth;
        }
      }

      return Positioned(
        width: w,
        child: CompositedTransformFollower(
          link: this._layerLink,
          showWhenUnlinked: false,
          offset: Offset(
              suggestionsBoxDecoration.offsetX,
              (_suggestionsBox!.direction == AxisDirection.down
                      ? _suggestionsBox!.textBoxHeight + 0.50
                      : _suggestionsBox!.directionUpOffset) +
                  5),
          child: _suggestionsBox!.direction == AxisDirection.down
              ? suggestionsList
              : FractionalTranslation(
                  translation:
                      const Offset(0.0, -1.0), // visually flips list to go up
                  child: suggestionsList,
                ),
        ),
      );
    });
  }

  void _onFocusChanged() {
    if (_focusNode!.hasFocus) {
      _openInputConnection();
      this._suggestionsBox!.open();
    } else {
      _closeInputConnectionIfNeeded();
      this._suggestionsBox!.close();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _closeInputConnectionIfNeeded();
    this._suggestionsBox!.close();
    this._suggestionsBox!.widgetMounted = false;
    WidgetsBinding.instance.removeObserver(this);

    _focusNode!.removeListener(_onFocusChanged);
    _resizeOnScrollTimer?.cancel();
    _scrollPosition?.removeListener(_scrollResizeListener);
    super.dispose();
  }

  void _openInputConnection() {
    if (!_hasInputConnection) {
      _connection = TextInput.attach(this, const TextInputConfiguration());
      _connection!.setEditingState(_value);
    }
    _connection!.show();
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _connection!.close();
      _connection = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    var chipsChildren = _chips
        .map<Widget>(
          (data) => widget.chipBuilder(context, this, data),
        )
        .toList();

    chipsChildren.add(
      SizedBox(
        height: 32.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                text,
                textAlign: TextAlign.center,
              ),
            ),
            _TextCaret(
              resumed: _focusNode!.hasFocus,
            ),
          ],
        ),
      ),
    );

    return CompositedTransformTarget(
      link: this._layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: requestKeyboard,
            child: InputDecorator(
              decoration: widget.decoration,
              isFocused: _focusNode!.hasFocus,
              isEmpty: _value.text.isEmpty,
              child: Wrap(
                spacing: 4.0,
                runSpacing: 4.0,
                children: chipsChildren,
              ),
            ),
          ),
          // _hasInputConnection
          //     ? SingleChildScrollView(
          //         child: Container(
          //           constraints: BoxConstraints(
          //               maxHeight: (_suggestions?.length ?? 0) == 0 ? 0 : 200),
          //           child: ListView(
          //             shrinkWrap: true,
          //             children: List.generate(_suggestions?.length ?? 0, (index) {
          //               return widget.suggestionBuilder(
          //                   context, this, _suggestions![index]);
          //             }),
          //           ),
          //         ),
          //       )
          //     : const SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    final oldCount = _countReplacements(_value);
    final newCount = _countReplacements(value);
    setState(() {
      // if (newCount < oldCount) {
      //   _chips = Set.from(_chips.take(newCount));
      // }-
      _value = value;
    });
    textEditingController.value = _value;
    _onSearchChanged(text);
  }

  int _countReplacements(TextEditingValue value) {
    return value.text.codeUnits
        .where((ch) => ch == kObjectReplacementChar)
        .length;
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // Not required
  }

  @override
  void connectionClosed() {
    _focusNode!.unfocus();
  }

  @override
  void performAction(TextInputAction action) {
    _focusNode!.unfocus();
  }

  void _updateTextInputState() {
    final text =
        String.fromCharCodes(_chips.map((_) => kObjectReplacementChar));
    _value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange(start: 0, end: text.length),
    );
    _connection?.setEditingState(_value);
  }

  void _onSearchChanged(String value) async {
    final localId = ++_searchId;
    final results = await widget.suggestionsCallback(value);
    if (_searchId == localId && mounted) {
      setState(() => _suggestions = results
          .where((profile) => !_chips.contains(profile))
          .cast<T>()
          .toList(growable: false));
    }
  }

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // TODO: implement performPrivateCommand
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // TODO: implement showAutocorrectionPromptRect
  }

  @override
  void showToolbar() {
    // TODO: implement showToolbar
  }
}

class _TextCaret extends StatefulWidget {
  const _TextCaret({
    Key? key,
    this.duration = const Duration(milliseconds: 500),
    this.resumed = false,
  }) : super(key: key);

  final Duration duration;
  final bool resumed;

  @override
  _TextCursorState createState() => _TextCursorState();
}

class _TextCursorState extends State<_TextCaret>
    with SingleTickerProviderStateMixin {
  bool _displayed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.duration, _onTimer);
  }

  void _onTimer(Timer timer) {
    setState(() => _displayed = !_displayed);
  }

  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Opacity(
        opacity: _displayed && widget.resumed ? 1.0 : 0.0,
        child: Container(
          width: 2.0,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}

class _MGChipSuggestionsList<T> extends StatefulWidget {
  final _MGChipSuggestionsBox? suggestionsBox;
  final TextEditingController? controller;
  final bool getImmediateSuggestions;
  final SuggestionSelectionCallback<T>? onSuggestionSelected;
  final SuggestionsCallback<T>? suggestionsCallback;
  final ItemBuilder<T>? itemBuilder;
  final ScrollController? scrollController;
  final SuggestionsBoxDecoration? decoration;
  final Duration? debounceDuration;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? noItemsFoundBuilder;
  final ErrorBuilder? errorBuilder;
  final AnimationTransitionBuilder? transitionBuilder;
  final Duration? animationDuration;
  final double? animationStart;
  final AxisDirection? direction;
  final bool? hideOnLoading;
  final bool? hideOnEmpty;
  final bool? hideOnError;
  final bool? keepSuggestionsOnLoading;
  final int? minCharsForSuggestions;

  _MGChipSuggestionsList({
    required this.suggestionsBox,
    this.controller,
    this.getImmediateSuggestions: false,
    this.onSuggestionSelected,
    this.suggestionsCallback,
    this.itemBuilder,
    this.scrollController,
    this.decoration,
    this.debounceDuration,
    this.loadingBuilder,
    this.noItemsFoundBuilder,
    this.errorBuilder,
    this.transitionBuilder,
    this.animationDuration,
    this.animationStart,
    this.direction,
    this.hideOnLoading,
    this.hideOnEmpty,
    this.hideOnError,
    this.keepSuggestionsOnLoading,
    this.minCharsForSuggestions,
  });

  @override
  _SuggestionsListState<T> createState() => _SuggestionsListState<T>();
}

class _SuggestionsListState<T> extends State<_MGChipSuggestionsList<T>>
    with SingleTickerProviderStateMixin {
  Iterable<T>? _suggestions;
  late bool _suggestionsValid;
  late VoidCallback _controllerListener;
  Timer? _debounceTimer;
  bool? _isLoading, _isQueued;
  Object? _error;
  AnimationController? _animationController;
  String? _lastTextValue;
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  _SuggestionsListState() {
    this._controllerListener = () {
      // If we came here because of a change in selected text, not because of
      // actual change in text
      if (widget.controller!.text == this._lastTextValue) return;

      this._lastTextValue = widget.controller!.text;

      this._debounceTimer?.cancel();
      if (widget.controller!.text.length < widget.minCharsForSuggestions!) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _suggestions = null;
            _suggestionsValid = true;
          });
        }
        return;
      } else {
        this._debounceTimer = Timer(widget.debounceDuration!, () async {
          if (this._debounceTimer!.isActive) return;
          if (_isLoading!) {
            _isQueued = true;
            return;
          }

          await this.invalidateSuggestions();
          while (_isQueued!) {
            _isQueued = false;
            await this.invalidateSuggestions();
          }
        });
      }
    };
  }

  @override
  void didUpdateWidget(_MGChipSuggestionsList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller!.addListener(this._controllerListener);
    _getSuggestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getSuggestions();
  }

  @override
  void initState() {
    super.initState();

    this._animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    this._suggestionsValid = widget.minCharsForSuggestions! > 0 ? true : false;
    this._isLoading = false;
    this._isQueued = false;
    this._lastTextValue = widget.controller!.text;

    if (widget.getImmediateSuggestions) {
      this._getSuggestions();
    }

    widget.controller!.addListener(this._controllerListener);
  }

  Future<void> invalidateSuggestions() async {
    _suggestionsValid = false;
    await _getSuggestions();
  }

  Future<void> _getSuggestions() async {
    if (_suggestionsValid) return;
    _suggestionsValid = true;

    if (mounted) {
      setState(() {
        this._animationController!.forward(from: 1.0);

        this._isLoading = true;
        this._error = null;
      });

      Iterable<T>? suggestions;
      Object? error;

      try {
        suggestions =
            await widget.suggestionsCallback!(widget.controller!.text);
      } catch (e) {
        error = e;
      }

      if (this.mounted) {
        // if it wasn't removed in the meantime
        setState(() {
          double? animationStart = widget.animationStart;
          // allow suggestionsCallback to return null and not throw error here
          if (error != null || suggestions?.isEmpty == true) {
            animationStart = 1.0;
          }
          this._animationController!.forward(from: animationStart);

          this._error = error;
          this._isLoading = false;
          this._suggestions = suggestions;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController!.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEmpty =
        this._suggestions?.length == 0 && widget.controller!.text == "";
    if ((this._suggestions == null || isEmpty) &&
        this._isLoading == false &&
        this._error == null) return Container();

    Widget child;
    if (this._isLoading!) {
      if (widget.hideOnLoading!) {
        child = Container(height: 0);
      } else {
        child = createLoadingWidget();
      }
    } else if (this._error != null) {
      if (widget.hideOnError!) {
        child = Container(height: 0);
      } else {
        child = createErrorWidget();
      }
    } else if (this._suggestions!.isEmpty) {
      if (widget.hideOnEmpty!) {
        child = Container(height: 0);
      } else {
        child = createNoItemsFoundWidget();
      }
    } else {
      child = createSuggestionsWidget();
    }

    final animationChild = widget.transitionBuilder != null
        ? widget.transitionBuilder!(context, child, this._animationController)
        : SizeTransition(
            axisAlignment: -1.0,
            sizeFactor: CurvedAnimation(
                parent: this._animationController!,
                curve: Curves.fastOutSlowIn),
            child: child,
          );

    BoxConstraints constraints;
    if (widget.decoration!.constraints == null) {
      constraints = BoxConstraints(
        maxHeight: widget.suggestionsBox!.maxHeight,
      );
    } else {
      double maxHeight = min(widget.decoration!.constraints!.maxHeight,
          widget.suggestionsBox!.maxHeight);
      constraints = widget.decoration!.constraints!.copyWith(
        minHeight: min(widget.decoration!.constraints!.minHeight, maxHeight),
        maxHeight: maxHeight,
      );
    }

    var container = Material(
      elevation: widget.decoration!.elevation,
      color: widget.decoration!.color,
      shape: widget.decoration!.shape,
      borderRadius: widget.decoration!.borderRadius,
      shadowColor: widget.decoration!.shadowColor,
      clipBehavior: widget.decoration!.clipBehavior,
      child: ConstrainedBox(
        constraints: constraints,
        child: animationChild,
      ),
    );

    return container;
  }

  Widget createLoadingWidget() {
    Widget child;

    if (widget.keepSuggestionsOnLoading! && this._suggestions != null) {
      if (this._suggestions!.isEmpty) {
        child = createNoItemsFoundWidget();
      } else {
        child = createSuggestionsWidget();
      }
    } else {
      child = widget.loadingBuilder != null
          ? widget.loadingBuilder!(context)
          : const Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            );
    }

    return child;
  }

  Widget createErrorWidget() {
    return widget.errorBuilder != null
        ? widget.errorBuilder!(context, this._error)
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Error: ${this._error}',
              style: TextStyle(color: Theme.of(context).errorColor),
            ),
          );
  }

  Widget createNoItemsFoundWidget() {
    return widget.noItemsFoundBuilder != null
        ? widget.noItemsFoundBuilder!(context)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text(
              'No Items Found!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).disabledColor, fontSize: 16.0),
            ),
          );
  }

  Widget createSuggestionsWidget() {
    Widget child = ListView(
      padding: EdgeInsets.zero,
      primary: false,
      shrinkWrap: true,
      controller: _scrollController,
      reverse:
          widget.suggestionsBox!.direction == AxisDirection.down ? false : true,
      // reverses the list to start at the bottom
      children: this._suggestions!.map((T suggestion) {
        return InkWell(
          child: widget.itemBuilder!(context, suggestion),
          onTap: () {
            widget.onSuggestionSelected!(suggestion);
          },
        );
      }).toList(),
    );

    if (widget.decoration!.hasScrollbar) {
      child = Scrollbar(
        controller: _scrollController,
        child: child,
      );
    }

    return child;
  }
}

/// Supply an instance of this class to the [TypeAhead.suggestionsBoxDecoration]
/// property to configure the suggestions box decoration
class SuggestionsBoxDecoration {
  /// The z-coordinate at which to place the suggestions box. This controls the size
  /// of the shadow below the box.
  ///
  /// Same as [Material.elevation](https://docs.flutter.io/flutter/material/Material/elevation.html)
  final double elevation;

  /// The color to paint the suggestions box.
  ///
  /// Same as [Material.color](https://docs.flutter.io/flutter/material/Material/color.html)
  final Color? color;

  /// Defines the material's shape as well its shadow.
  ///
  /// Same as [Material.shape](https://docs.flutter.io/flutter/material/Material/shape.html)
  final ShapeBorder? shape;

  /// Defines if a scrollbar will be displayed or not.
  final bool hasScrollbar;

  /// If non-null, the corners of this box are rounded by this [BorderRadius](https://docs.flutter.io/flutter/painting/BorderRadius-class.html).
  ///
  /// Same as [Material.borderRadius](https://docs.flutter.io/flutter/material/Material/borderRadius.html)
  final BorderRadius? borderRadius;

  /// The color to paint the shadow below the material.
  ///
  /// Same as [Material.shadowColor](https://docs.flutter.io/flutter/material/Material/shadowColor.html)
  final Color shadowColor;

  /// The constraints to be applied to the suggestions box
  final BoxConstraints? constraints;

  /// Adds an offset to the suggestions box
  final double offsetX;

  /// The content will be clipped (or not) according to this option.
  ///
  /// Same as [Material.clipBehavior](https://api.flutter.dev/flutter/material/Material/clipBehavior.html)
  final Clip clipBehavior;

  /// Creates a SuggestionsBoxDecoration
  const SuggestionsBoxDecoration(
      {this.elevation: 4.0,
      this.color,
      this.shape,
      this.hasScrollbar: true,
      this.borderRadius,
      this.shadowColor: const Color(0xFF000000),
      this.constraints,
      this.clipBehavior: Clip.none,
      this.offsetX: 0.0});
}

class _MGChipSuggestionsBox {
  static const int waitMetricsTimeoutMillis = 1000;
  static const double minOverlaySpace = 64.0;

  final BuildContext context;
  final AxisDirection desiredDirection;
  final bool autoFlipDirection;

  OverlayEntry? _overlayEntry;
  AxisDirection direction;

  double suggestionsBoxVerticalOffset = 10.0;

  bool isOpened = false;
  bool widgetMounted = true;
  double maxHeight = 300.0;
  double textBoxWidth = 100.0;
  double textBoxHeight = 100.0;
  late double directionUpOffset;

  _MGChipSuggestionsBox(this.context, this.direction, this.autoFlipDirection)
      : desiredDirection = direction;

  void open() {
    if (this.isOpened) return;
    assert(this._overlayEntry != null);
    resize();
    Overlay.of(context)!.insert(this._overlayEntry!);
    this.isOpened = true;
  }

  void close() {
    if (!this.isOpened) return;
    assert(this._overlayEntry != null);
    this._overlayEntry!.remove();
    this.isOpened = false;
  }

  void toggle() {
    if (this.isOpened) {
      this.close();
    } else {
      this.open();
    }
  }

  MediaQuery? _findRootMediaQuery() {
    MediaQuery? rootMediaQuery;
    context.visitAncestorElements((element) {
      if (element.widget is MediaQuery) {
        rootMediaQuery = element.widget as MediaQuery;
      }
      return true;
    });

    return rootMediaQuery;
  }

  /// Delays until the keyboard has toggled or the orientation has fully changed
  Future<bool> _waitChangeMetrics() async {
    if (widgetMounted) {
      // initial viewInsets which are before the keyboard is toggled
      EdgeInsets initial = MediaQuery.of(context).viewInsets;
      // initial MediaQuery for orientation change
      MediaQuery? initialRootMediaQuery = _findRootMediaQuery();

      int timer = 0;
      // viewInsets or MediaQuery have changed once keyboard has toggled or orientation has changed
      while (widgetMounted && timer < waitMetricsTimeoutMillis) {
        // TODO: reduce delay if showDialog ever exposes detection of animation end
        await Future<void>.delayed(const Duration(milliseconds: 170));
        timer += 170;

        if (widgetMounted &&
            (MediaQuery.of(context).viewInsets != initial ||
                _findRootMediaQuery() != initialRootMediaQuery)) {
          return true;
        }
      }
    }

    return false;
  }

  void resize() {
    // check to see if widget is still mounted
    // user may have closed the widget with the keyboard still open
    if (widgetMounted) {
      _adjustMaxHeightAndOrientation();
      _overlayEntry!.markNeedsBuild();
    }
  }

  // See if there's enough room in the desired direction for the overlay to display
  // correctly. If not, try the opposite direction if things look more roomy there
  void _adjustMaxHeightAndOrientation() {
    ChipsInput<dynamic> widget = context.widget as ChipsInput<dynamic>;

    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || box.hasSize == false) {
      return;
    }

    textBoxWidth = box.size.width;
    textBoxHeight = box.size.height;

    // top of text box
    double textBoxAbsY = box.localToGlobal(Offset.zero).dy;

    // height of window
    double windowHeight = MediaQuery.of(context).size.height;

    // we need to find the root MediaQuery for the unsafe area height
    // we cannot use BuildContext.ancestorWidgetOfExactType because
    // widgets like SafeArea creates a new MediaQuery with the padding removed
    MediaQuery rootMediaQuery = _findRootMediaQuery()!;

    // height of keyboard
    double keyboardHeight = rootMediaQuery.data.viewInsets.bottom;

    double maxHDesired = _calculateMaxHeight(desiredDirection, box, widget,
        windowHeight, rootMediaQuery, keyboardHeight, textBoxAbsY);

    // if there's enough room in the desired direction, update the direction and the max height
    if (maxHDesired >= minOverlaySpace || !autoFlipDirection) {
      direction = desiredDirection;
      maxHeight = maxHDesired;
    } else {
      // There's not enough room in the desired direction so see how much room is in the opposite direction
      AxisDirection flipped = flipAxisDirection(desiredDirection);
      double maxHFlipped = _calculateMaxHeight(flipped, box, widget,
          windowHeight, rootMediaQuery, keyboardHeight, textBoxAbsY);

      // if there's more room in this opposite direction, update the direction and maxHeight
      if (maxHFlipped > maxHDesired) {
        direction = flipped;
        maxHeight = maxHFlipped;
      }
    }

    if (maxHeight < 0) maxHeight = 0;
  }

  double _calculateMaxHeight(
      AxisDirection direction,
      RenderBox box,
      ChipsInput<dynamic> widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    return direction == AxisDirection.down
        ? _calculateMaxHeightDown(box, widget, windowHeight, rootMediaQuery,
            keyboardHeight, textBoxAbsY)
        : _calculateMaxHeightUp(box, widget, windowHeight, rootMediaQuery,
            keyboardHeight, textBoxAbsY);
  }

  double _calculateMaxHeightDown(
      RenderBox box,
      ChipsInput<dynamic> widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    // unsafe area, ie: iPhone X 'home button'
    // keyboardHeight includes unsafeAreaHeight, if keyboard is showing, set to 0
    double unsafeAreaHeight =
        keyboardHeight == 0 ? rootMediaQuery.data.padding.bottom : 0;

    return windowHeight -
        keyboardHeight -
        unsafeAreaHeight -
        textBoxHeight -
        textBoxAbsY -
        2 * suggestionsBoxVerticalOffset;
  }

  double _calculateMaxHeightUp(
      RenderBox box,
      ChipsInput<dynamic> widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    // recalculate keyboard absolute y value
    double keyboardAbsY = windowHeight - keyboardHeight;

    directionUpOffset = textBoxAbsY > keyboardAbsY
        ? keyboardAbsY - textBoxAbsY - suggestionsBoxVerticalOffset
        : -suggestionsBoxVerticalOffset;

    // unsafe area, ie: iPhone X notch
    double unsafeAreaHeight = rootMediaQuery.data.padding.top;

    return textBoxAbsY > keyboardAbsY
        ? keyboardAbsY - unsafeAreaHeight - 2 * suggestionsBoxVerticalOffset
        : textBoxAbsY - unsafeAreaHeight - 2 * suggestionsBoxVerticalOffset;
  }

  Future<void> onChangeMetrics() async {
    if (await _waitChangeMetrics()) {
      resize();
    }
  }
}

/// Supply an instance of this class to the [TypeAhead.suggestionsBoxController]
/// property to manually control the suggestions box
class MGChipSuggestionsBoxController {
  _MGChipSuggestionsBox? _suggestionsBox;
  FocusNode? _effectiveFocusNode;

  /// Opens the suggestions box
  void open() {
    _effectiveFocusNode!.requestFocus();
  }

  bool isOpened() {
    return _suggestionsBox!.isOpened;
  }

  /// Closes the suggestions box
  void close() {
    _effectiveFocusNode!.unfocus();
  }

  /// Opens the suggestions box if closed and vice-versa
  void toggle() {
    if (_suggestionsBox!.isOpened) {
      close();
    } else {
      open();
    }
  }

  /// Recalculates the height of the suggestions box
  void resize() {
    _suggestionsBox!.resize();
  }
}
