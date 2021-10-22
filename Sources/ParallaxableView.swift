//
//  ParallaxableView.swift
//  Parallaxable
//
//  Created by SAGESSE on 2020/12/30.
//

import UIKit
import SwiftUI


/// A container that split the data arranged into mut page, optionally providing float view
/// to custom navigation bar/fold content/pinned footer.
///
/// In its simplest form, a parallaxable view creates its contents statically, as shown in the following example:
/// ```
/// var body: some View {
///     ParallaxableView {
///         Text("A Page")
///         Text("A Second Page")
///         Text("A Third Page")
///     }
/// }
/// ```
public struct ParallaxableView: View {
    
    /// Creates a parallaxable view with the given page content that supports selecting.
    ///
    /// - Parameters:
    ///   - selection: A binding to that identifies selected index.
    ///   - content: The page content of the parallaxable view.
    public init(selection: Binding<Int>? = nil, @ParallaxableBuilder content: () -> ParallaxableContent) {
        self.content = content()
        self.selection = selection
    }
    
    /// The content of parallaxable view.
    public var body: some View {
        _XCParallaxableViewContainer(content: content, selection: selection, configuration: configuration)
            .transformPreference(_XCParallaxableViewConfiguration.self) {
                $0.append(configuration)
            }
            .onPreferenceChange(_XCParallaxableViewProxy.self) {
                $0.forEach {
                    if $0.configuration == nil {
                        $0.configuration = configuration
                    }
                }
            }
    }
    
    private let content: ParallaxableContent
    private let selection: Binding<Int>?
    private let configuration: _XCParallaxableViewConfiguration = .init()
}

public extension ParallaxableView {
    
    /// Adds a condition that prevents float content bounces past the edge of contet size and back again.
    ///
    /// - parameter isDisabled: A Boolean that indicates whether bouncing is prevented.
    func verticalBouncesDisabled(_ isDisabled: Bool = true) -> Self {
        _parallaxableConfiguration {
            $0.disablesBounceVertical = isDisabled
        }
    }
    
    ///  Adds a condition that prevents page content bounces past the edge of contet size and back again.
    ///
    /// - parameter isDisabled: A Boolean that indicates whether bouncing is prevented.
    func horizontalBouncesDisabled(_ isDisabled: Bool = true) -> Self {
        _parallaxableConfiguration {
            $0.disablesBounceHorizontal = isDisabled
        }
    }
    
    /// Clips this view and content view to bar/scrollable bounding rectangular frame.
    ///
    /// Use the `clipped(antialiased:)` modifier to hide any content that
    /// extends beyond the layout bounds of the shape.
    ///
    /// By default, a view's bounding frame is used only for layout, so any
    /// content that extends beyond the edges of the frame is still visible.
    ///
    /// - Parameter antialiased: A Boolean value that indicates whether the
    ///   rendering system applies smoothing to the edges of the clipping
    ///   rectangle.
    func clipped(antialiased: Bool = false) -> Self {
        _parallaxableConfiguration {
            $0.isClipped = true
            $0.isAntialiased = antialiased
        }
    }
    
    /// Adds an action to perform when the parallaxable view value changes.
    ///
    /// - Parameter action: The action to perform when this parallaxable view value
    ///   changes. The `action` closure's parameter contains the parallaxable view new
    ///   value.
    func onChanged(action: @escaping (CGPoint) -> Void) -> Self {
        _parallaxableConfiguration {
            $0.contentOffsetObservers.append(action)
        }
    }
    
    /// The header view is float view displaying in navigation bar.
    func parallaxableHeader<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.headerView)
    }
    /// The content view is foldable view displaying after of header view.
    func parallaxableContent<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.contentView)
    }
    /// The footer view is pinable view displaying after of content view.
    func parallaxableFooter<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.footerView)
    }
    
    /// The overlay view is resizable view displaying in top of all views.
    func parallaxableOverlay<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.overlayView)
    }
    /// The background view is resizable view displaying in bottom of all views.
    func parallaxableBackground<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.backgroundView)
    }
    
    /// The header view is float view displaying in navigation bar.
    func parallaxableHeader<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableHeader(view())
    }
    /// The content view is foldable view displaying after of header view.
    func parallaxableContent<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableContent(view())
    }
    /// The footer view is pinable view displaying after of content view.
    func parallaxableFooter<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableFooter(view())
    }
    
    /// The overlay view is resizable view displaying in top of all views.
    func parallaxableOverlay<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableOverlay(view())
    }
    /// The background view is resizable view displaying in bottom of all views.
    func parallaxableBackground<T: View>(@ViewBuilder view: () -> T) -> Self {
        parallaxableBackground(view())
    }
    
    /// Configures a custom SwiftUI.View to the specified key path.
    private func _parallaxableCustomView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIViewController?>) -> Self {
        _parallaxableConfiguration {
            $0.handlers[keyPath] = {
                $0.setWrapperView(view, for: keyPath)
            }
        }
    }
    private func _parallaxableConfiguration(block: ( _XCParallaxableViewConfiguration) -> ())  -> Self {
        block(configuration)
        return self
    }
}


// MARK: -


/// A proxy value that supports programmatic scrolling of the scrollable
/// views within a view hierarchy.
///
/// You don't create instances of ``ParallaxableViewProxy`` directly. Instead, your
/// ``ParallaxableViewReader`` receives an instance of ``ParallaxableViewProxy`` in its
/// `content` view builder. You use actions within this view builder, such
/// as button and gesture handlers or the ``ParallaxableView/onParallaxableChanged(action:)``
/// method, to call the proxy's ``ParallaxableViewProxy/scrollTo(_:anchor:)`` method.
public struct ParallaxableViewProxy {
    
    /// The frame rectangle of the parallaxable view.
    public var frame: CGRect {
        return forwarding.frame
    }
    
    /// The size of the parallaxable view presentation content.
    public var contentSize: CGSize {
        forwarding.contentSize
    }
    
    public var contentOffset: CGPoint {
        get { forwarding.contentOffset }
        nonmutating set { forwarding.contentOffset = newValue }
    }
    
    public func setContentOffset(_ newContentOffset: CGPoint, animated: Bool) {
        forwarding.setContentOffset(newContentOffset, animated: animated)
    }
    
    fileprivate var forwarding: _XCParallaxableViewProxy = .init()
}

/// A view that provides programmatic scrolling, by working with a proxy
/// to scroll to known child views.
///
/// The scroll view reader's content view builder receives a ``ParallaxableViewProxy``
/// instance; you use the proxy's ``ParallaxableViewProxy/scrollTo(_:anchor:)`` to
/// perform scrolling.
///
/// The following example creates a ``ParallaxableView`` containing 100 views that
/// together display a color gradient. It also contains two buttons, one each
/// at the top and bottom. The top button tells the ``ParallaxableViewProxy`` to
/// scroll to the bottom button, and vice versa.
///
///     var body: some View {
///         ParallaxableViewReader { proxy in
///             ParallaxableView {
///                 ScrollView {
///                     VStack(spacing: 0) {
///                         ForEach(0..<100) { i in
///                             color(fraction: Double(i) / 100)
///                                 .frame(height: 32)
///                         }
///                     }
///                 }
///                 .overlay(Button("Move to down") {
///                     withAnimation {
///                         proxy.contentOffset.y += 10
///                     }
///                 })
///             }
///         }
///     }
///
///     func color(fraction: Double) -> Color {
///         Color(red: fraction, green: 1 - fraction, blue: 0.5)
///     }
///
/// > Important: You may not use the ``ParallaxableViewProxy``
/// during execution of the `content` view builder; doing so results in a
/// runtime error. Instead, only actions created within `content` can call
/// the proxy, such as gesture handlers or a view's `onChange(of:perform:)`
/// method.
public struct ParallaxableViewReader<Content: View>: View {
    
    /// The view builder that creates the reader's content.
    public var content: (ParallaxableViewProxy) -> Content
    
    /// Creates an instance that can perform programmatic scrolling of its
    /// child scroll views.
    ///
    /// - Parameter content: The reader's content, containing one or more
    /// scroll views. This view builder receives a ``ParallaxableViewProxy``
    /// instance that you use to perform scrolling.
    public init(@ViewBuilder content: @escaping (ParallaxableViewProxy) -> Content) {
        self.content = content
    }
    
    /// The content and behavior of the view.
    public var body: some View {
        content(proxy)
            .transformPreference(_XCParallaxableViewProxy.self) {
                $0.append(proxy.forwarding)
            }
            .onPreferenceChange(_XCParallaxableViewConfiguration.self) {
                proxy.forwarding.configuration = $0.last
            }
    }
    
    private var proxy: ParallaxableViewProxy = .init()
}


// MARK: -


public struct ParallaxableContent: View {
    
    public var body: Never {
        fatalError("body has not been implemented")
    }
    
    public init<T: View>(_ view: T) {
        self.init([view])
    }
    public init<T: View>(_ views: [T]) {
        self.builders = views.flatMap { view in
            return (view as? Self)?.builders ?? [{
                return $0.dequeueReusableHostingController(view)
            }]
        }
    }
    public init(_ views: Self...) {
        self.builders = views.flatMap(\.builders)
    }
    
    fileprivate func build(_ coordinator: _XCParallaxableViewCoordinator) -> [UIViewController] {
        return builders.map {
            return $0(coordinator)
        }
    }
    
    private let builders: [(_XCParallaxableViewCoordinator) -> UIViewController]
}


// MARK: -


/// [@resultBuilder](https://github.com/apple/swift-evolution/blob/main/proposals/0289-result-builders.md)
@resultBuilder
public struct ParallaxableBuilder {
    
    
    public static func buildBlock() -> ParallaxableContent {
        .init()
    }
    public static func buildBlock<C0: View>(_ c0: C0) -> ParallaxableContent {
        .init(.init(c0))
    }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> ParallaxableContent {
        .init(.init(c0), .init(c1))
    }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7), .init(c8))
    }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> ParallaxableContent {
        .init(.init(c0), .init(c1), .init(c2), .init(c3), .init(c4), .init(c5), .init(c6), .init(c7), .init(c8), .init(c9))
    }
    
    /// Enables support for `if` statements that do not have an `else`.
    public static func buildOptional<C: View>(_ content: C?) -> C? {
        content // ignore, content is ParallaxableContent already.
    }
    
    /// With buildEither(first:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    public static func buildEither<C: View>(first view: C) -> ParallaxableContent {
        .init(view)
    }
    /// With buildEither(second:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    public static func buildEither<C: View>(second view: C) -> ParallaxableContent {
        .init(view)
    }
    
    /// Enables support for 'for..in' loops by combining the
    /// results of all iterations into a single result.
    public static func buildArray<C: View>(_ views: [C]) -> ParallaxableContent {
        .init(views)
    }
}


// MARK: -


fileprivate class _XCParallaxableViewProxy: NSObject, PreferenceKey {
    
    static var defaultValue: [_XCParallaxableViewProxy] = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
    
    var frame: CGRect {
        parallaxableController?.viewIfLoaded?.frame ?? .zero
    }
    
    var contentSize: CGSize {
        parallaxableController?.contentSize ?? .zero
    }
    
    var contentOffset: CGPoint {
        get { parallaxableController?.contentOffset ?? .zero }
        set { parallaxableController?.contentOffset = newValue }
    }
    
    func setContentOffset(_ newContentOffset: CGPoint, animated: Bool) {
        parallaxableController?.setContentOffset(newContentOffset, animated: animated)
    }
    
    var parallaxableController: XCParallaxableController? {
        return configuration?.coordinator?.parallaxableController
    }
    
    weak var configuration: _XCParallaxableViewConfiguration?
}

fileprivate class _XCParallaxableViewConfiguration: NSObject, PreferenceKey {
    
    static var defaultValue: [_XCParallaxableViewConfiguration] = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
    
    var isClipped: Bool = false
    var isAntialiased: Bool = false
    
    var disablesBounceVertical: Bool = false
    var disablesBounceHorizontal: Bool = false
    
    var handlers: [AnyKeyPath: (_XCParallaxableViewCoordinator) -> ()] = [:]
    
    var contentOffsetObservers: [(CGPoint) -> ()] = []
    
    weak var coordinator: _XCParallaxableViewCoordinator?
}


// MARK: -


/// Maybe let ``ParallaxableView`` conforms to ``UIViewControllerRepresentable`` protocol is better,
/// But we don't want to public internal details.
fileprivate struct _XCParallaxableViewContainer: UIViewControllerRepresentable {
    
    /// The all pages content.
    let content: ParallaxableContent
    /// The selected page index.
    let selection: Binding<Int>?
    /// The contianer configuration.
    let configuration: _XCParallaxableViewConfiguration
    
    /// Build a new coordinator in first rendered.
    func makeCoordinator() -> _XCParallaxableViewCoordinator {
        return .init()
    }
    
    /// Using shared parallaxable controller.
    func makeUIViewController(context: Context) -> XCParallaxableController {
        return context.coordinator.parallaxableController
    }
    
    /// Update all pages content in to coordinator of the current context.
    func updateUIViewController(_ viewController: UIViewControllerType, context: Context) {
        context.coordinator.performWithoutContentChanges {
            $0.apply(configuration)
            $0.setContentView(content)
            $0.setContentSection(selection, animated: !context.transaction.disablesAnimations)
        }
    }
}


// MARK: -


/// SwiftUI will retain and manages an coordinator, when a view is rendered, coordinator are reusable.
//@dynamicMemberLookup
fileprivate class _XCParallaxableViewCoordinator: XCParallaxableControllerDelegate {
    
    /// The context shared parallaxable controller.
    var parallaxableController: XCParallaxableController
    
    /// The header view is float view displaying in navigation bar.
    var headerView: UIViewController? {
        willSet {
            parallaxableController.headerView = newValue?.view
        }
    }
    /// The content view is foldable view displaying after of header view.
    var contentView: UIViewController? {
        willSet {
            parallaxableController.contentView = newValue?.view
        }
    }
    /// The footer view is pinable view displaying after of content view.
    var footerView: UIViewController? {
        willSet {
            parallaxableController.footerView = newValue?.view
        }
    }
    
    /// The overlay view is resizable view displaying in top of all views.
    var overlayView: UIViewController? {
        willSet {
            setDecoratingView(newValue, from: overlayView)
        }
    }
    /// The background view is resizable view displaying in bottom of all views.
    var backgroundView: UIViewController? {
        willSet {
            setDecoratingView(newValue, from: overlayView, at: 0)
        }
    }
    
    /// Update the all pages content to shared parallaxable controller.
    func setContentView(_ pages: ParallaxableContent) {
        // Add the current view controllers to the reuse queue, this is a big performance boost.
        reusableHostingControllers = parallaxableController.viewControllers
        
        // The builder will call `dequeueReusableHostingController<T>(_ view: T) -> UIViewController` to a hosting controller,
        // It will reuse the old hosting controller as much as possible.
        parallaxableController.viewControllers = pages.build(self)
        
        // Remove all unused view controllers.
        reusableHostingControllers = nil
    }
    
    /// Apply the selection.
    func setContentSection(_ selection: Binding<Int>?, animated: Bool) {
        // Prepare the callback context.
        selectedIndexObserver = selection
        
        // Synchronize the selected index of the selection.
        let newSelectedIndex = selection?.wrappedValue ?? 0
        guard newSelectedIndex != parallaxableController.selectedIndex else {
            return
        }
        parallaxableController.setSelectedIndex(newSelectedIndex, animated: animated)
    }
    
    /// Update new view for parallaxing view.
    func setWrapperView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIViewController?>) {
        // For `EmptyView` we not need to create a wrapper view.
        if view is EmptyView {
            self[keyPath: keyPath] = nil
            return
        }
        // Try to reuse wrapper view for new content.
        if let wrapper = self[keyPath: keyPath] as? _XCParallaxableHostingController<T> {
            wrapper.rootView = view
            return
        }
        let hostingController = _XCParallaxableHostingController(rootView: view)
        hostingController.isDecoratingView = keyPath == \.backgroundView || keyPath == \.overlayView
        self[keyPath: keyPath] = hostingController
    }
    /// Update the decorating view for parallaxing view.
    func setDecoratingView(_ newValue: UIViewController?, from oldValue: UIViewController?, at index: Int? = nil) {
        guard newValue !== oldValue else {
            return
        }
        // Remove the old decorating view if added.
        oldValue?.viewIfLoaded?.removeFromSuperview()
        guard let newValue = newValue else {
            return
        }
        
        // Setup the new decorating view.
        let parallaxingView = parallaxableController.parallaxingView
        parallaxingView.insertSubview(newValue.view, at: index ?? parallaxingView.subviews.count - 1)
        NSLayoutConstraint.activate([
            newValue.view.topAnchor.constraint(equalTo: parallaxingView.topAnchor),
            newValue.view.leftAnchor.constraint(equalTo: parallaxingView.leftAnchor),
            newValue.view.rightAnchor.constraint(equalTo: parallaxingView.rightAnchor),
            newValue.view.bottomAnchor.constraint(equalTo: parallaxingView.bottomAnchor),
        ])
        
    }
    
    /// Apply the configuration.
    func apply(_ configuration: _XCParallaxableViewConfiguration) {
        // Apply configuration to parallaxable controller.
        contentOffsetObservers = configuration.contentOffsetObservers
        parallaxableController.isClipped = configuration.isClipped
        parallaxableController.disablesBounceVertical = configuration.disablesBounceVertical
        parallaxableController.disablesBounceHorizontal = configuration.disablesBounceHorizontal
        
        // Apply `SwiftUI.View` changes in to subview.
        configuration.coordinator = self
        configuration.handlers.values.forEach {
            $0(self)
        }
        
        // Make sure the backgroundView/overlayView in the right view hierarchy.
        backgroundView?.view.map(parallaxableController.parallaxingView.sendSubviewToBack)
        overlayView?.view.map(parallaxableController.parallaxingView.bringSubviewToFront)
    }
    
    ///
    func dequeueReusableHostingController<T>(_ view: T) -> UIViewController where T: View {
        // Get the first reusable host controller of the compatible this content in the reuse queue.
        guard let index = reusableHostingControllers?.firstIndex(where: { $0 is UIHostingController<T> }) else {
            // Unable to find a reusable hosting controller in the reuse queue.
            return UIHostingController(rootView: view)
        }
        
        // Once a reusable hosting controller is found, remove it from the reuse queue.
        guard let controller = reusableHostingControllers?.remove(at: index) as? UIHostingController<T> else {
            // This is something that should never happen, but if happen create a new hosting controller.
            return UIHostingController(rootView: view)
        }
        
        // Replace the root view with content.
        controller.rootView = view
        return controller
    }
    
    func performWithoutContentChanges(_ actions: (_XCParallaxableViewCoordinator) -> ()) {
        isLockedContentChanges = true
        actions(self)
        isLockedContentChanges = false
    }
    
    func notifyChangesIfNeeded(_ newValue: CGPoint) {
        //
        guard lastNotifyedContentOffset != newValue else {
            return
        }
        lastNotifyedContentOffset = newValue
        contentOffsetObservers.forEach {
            $0(newValue)
        }
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didSelectItemAt index: Int) {
        guard !isLockedContentChanges else {
            return
        }
        // Notifiy selection the selected index is changes.
        guard let selection = selectedIndexObserver, selection.wrappedValue != index else {
            return
        }
        selection.wrappedValue = index
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didChangeContentOffset contentOffset: CGPoint) {
        guard !isLockedContentChanges else {
            return
        }
        notifyChangesIfNeeded(contentOffset)
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didAppear animated: Bool) {
        notifyChangesIfNeeded(parallaxableController.contentOffset)
    }
    
    init() {
        self.parallaxableController = .init()
        self.parallaxableController.delegate = self
    }
    
    private var isLockedContentChanges: Bool = false
    private var lastNotifyedContentOffset: CGPoint?
    
    private var reusableHostingControllers: [UIViewController]?
    
    private var contentOffsetObservers: [(CGPoint) -> ()] = []
    private var selectedIndexObserver: Binding<Int>?
}


// MARK: -


/// An `UIHostingController` compatible controller.
fileprivate class _XCParallaxableHostingController<Content: View>: UIHostingController<Content> {
    
    var isDecoratingView: Bool = false
    
    var intrinsicContentSize: CGSize {
        // For the decorating view does not require any intrinsic content size.
        guard !isDecoratingView else {
            return .zero
        }
        // The exact content needs to be calculated before getter.
        if cachedIntrinsicContentSize == nil {
            updateHeightConstraintsIfNeeded()
        }
        return cachedIntrinsicContentSize ?? .zero
    }
    
    func invalidateIntrinsicContentSize() {
        guard !isDecoratingView, !isLockedConentChanges else {
            return
        }
        cachedIntrinsicContentSize = nil
        view.invalidateIntrinsicContentSize()
    }
    
    override func loadView() {
        super.loadView()
        // The default background color is black, but we need to support alpha.
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Using multiple height constraints to control the size of the view.
        heightConstraint = (
            view.heightAnchor.constraint(lessThanOrEqualToConstant: 0),
            view.heightAnchor.constraint(equalToConstant: 0),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        )
        
        // Inject bug fix patch class.
        object_setClass(view, _XCParallaxableHostingView<Content>.self)
    }
    
    private func updateHeightConstraintsIfNeeded() {
        // Lock the content changes to avoid recursive calls.
        let oldValue = isLockedConentChanges
        isLockedConentChanges = true
        defer {
            isLockedConentChanges = oldValue
        }
        
        // Update the constraints of the current view when the estimated size changes.
        guard let (minHeight, maxHeight, height) = estimatedSize() else {
            return
        }
        
        let newValue = CGVector(dx: minHeight, dy: maxHeight)
        guard hostingEstimatedSize != newValue else {
            cachedIntrinsicContentSize = CGSize(width: UIView.noIntrinsicMetric, height: height)
            return
        }
        hostingEstimatedSize = newValue
        
        // The final hosting view height consists on multiple (le, eq, ge) height constraints.
        heightConstraint.map {
            // The equalTo(eq) constraint is calculate from the minSize and maxSize.
            $0.le.constant = maxHeight
            $0.eq.constant = height
            $0.ge.constant = minHeight
            // The equalTo(eq) constraint is activate only when the hosting view explicitly specified a size.
            $0.le.isActive = true
            $0.eq.isActive = minHeight == maxHeight
            $0.ge.isActive = true
        }
        // print("\(Content.self).\(#function) => \(minHeight) - \(height) - \(maxHeight)")
        
        // When the equalTo(eq) constraint is not active, the constraint engine requrired evaluates
        // the final size based on the content size.
        cachedIntrinsicContentSize = CGSize(width: UIView.noIntrinsicMetric, height: height)
    }
    
    private func estimatedSize() -> (CGFloat, CGFloat, CGFloat)? {
        // There is no need to estimate the size when the view is not ready.
        guard let width = view.window?.bounds.width else {
            return nil
        }
        var height = CGFloat(0)
        
        // Calculate the min size of the hosting view content.
        let compressedSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let minHeight = pixelate(sizeThatFits(in: compressedSize).height)
        if minHeight != compressedSize.height {
            height = max(minHeight, height)
        }
        
        // Calculate the max size of the hosting view content.
        let expandedSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let maxHeight = pixelate(sizeThatFits(in: expandedSize).height)
        if maxHeight != expandedSize.height {
            height = max(maxHeight, height)
        }
        
        return (minHeight, maxHeight, height)
    }
    
    private func pixelate(_ value: CGFloat) -> CGFloat {
        return trunc(value * 10) / 10
    }
    
    private var cachedIntrinsicContentSize: CGSize?
    
    private var  heightConstraint: (le: NSLayoutConstraint, eq: NSLayoutConstraint, ge: NSLayoutConstraint)?
    private var hostingEstimatedSize: CGVector?
    
    private var isLockedConentChanges: Bool = false
    
}

/// An `_UIHostingView` compatible view.
fileprivate class _XCParallaxableHostingView<Content: View>: _UIHostingView<Content> {
    
    /// This is a bug fix, because content does not require any safe area insets.
    override var safeAreaInsets: UIEdgeInsets {
        return .zero
    }
    
    /// In any time call `intrinsicContentSize` to always calculate actual content size.
    override var intrinsicContentSize: CGSize {
        return hostingController?.intrinsicContentSize ?? super.intrinsicContentSize
    }
    
    /// When the content size changes, the SwiftUI engine will call setNeedsLayout to reload view layout.
    /// Best solution is recive a content size changes notification in the future.
    override func setNeedsLayout() {
        super.setNeedsLayout()
        hostingController?.invalidateIntrinsicContentSize()
    }
    
    /// Get the hosting controller in view hierarchy context.
    @inline(__always) private var hostingController: _XCParallaxableHostingController<Content>? {
        return next as? _XCParallaxableHostingController<Content>
    }
}
