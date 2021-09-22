//
//  ParallaxableView.swift
//  Parallaxable
//
//  Created by SAGESSE on 2020/12/30.
//

import UIKit
import SwiftUI


/// A container that split the data arranged into each page, optionally providing the ability
/// to custom navigation bar/fold/pinned.
///
/// In its simplest form, a ParallaxableView creates its contents statically, as shown in the following example:
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

    public init(selection: Binding<Int>? = nil, @ParallaxableBuilder content: () -> ParallaxableContent) {
        self.content = content()
        self.selection = selection
    }

    public var body: some View {
        _XCParallaxableViewContainer(content: content, selection: selection, configuration: configuration)
    }

    private let content: ParallaxableContent
    private let selection: Binding<Int>?
    private let configuration: _XCParallaxableViewConfiguration = .init()
}

public extension ParallaxableView {
    
    func parallaxableClipped(antialiased: Bool = false) -> Self {
        _parallaxableConfiguration {
            $0.isClipped = true
            $0.isAntialiased = antialiased
        }
    }
    func onParallaxableChanged(action: @escaping (CGPoint) -> Void) -> Self {
        _parallaxableConfiguration {
            $0.contentOffsetObservers.append(action)
        }
    }

    func parallaxableHeader<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.headerView)
    }
    func parallaxableContent<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.contentView)
    }
    func parallaxableFooter<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.footerView)
    }
    
    func parallaxableOverlay<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.overlayView)
    }
    func parallaxableBackground<T: View>(_ view: T) -> Self {
        _parallaxableCustomView(view, for: \.backgroundView)
    }
    

    private func _parallaxableCustomView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIView?>) -> Self {
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


public struct ParallaxableViewProxy {
    
}

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
        if #available(iOS 14.0, *) {
            ScrollViewReader { _ in
                content(ParallaxableViewProxy())
            }
        } else {
            content(ParallaxableViewProxy())
        }
    }
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


// MARK: -


fileprivate class _XCParallaxableViewConfiguration {

//    static var defaultValue: _XCParallaxableViewConfiguration = .init()
    
    var isClipped: Bool = false
    var isAntialiased: Bool = false
    
    var handlers: [AnyKeyPath: (_XCParallaxableViewCoordinator) -> ()] = [:]
    
    var contentOffsetObservers: [(CGPoint) -> ()] = []
}

//fileprivate extension EnvironmentValues {
//
//    var _parallaxableViewConfiguration: _XCParallaxableViewConfiguration {
//        get { self[_XCParallaxableViewConfiguration.self] }
//        set { self[_XCParallaxableViewConfiguration.self] = newValue }
//    }
//}


// MARK: -


/// Maybe let `ParallaxableView` conforms to `UIViewControllerRepresentable` protocol is better,
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
        context.coordinator.apply(configuration)
        context.coordinator.setContentView(content)
        context.coordinator.setContentSection(selection, animated: !context.transaction.disablesAnimations)
    }
}


// MARK: -


/// SwiftUI will retain and manages an coordinator, when a view is rendered, coordinator are reusable.
@dynamicMemberLookup
fileprivate class _XCParallaxableViewCoordinator: XCParallaxableControllerDelegate {
    
    /// The context shared parallaxable controller.
    let parallaxableController: XCParallaxableController
    
    
    var backgroundView: UIView? {
        willSet {
            guard newValue !== backgroundView else {
                return
            }
            backgroundView.map {
                $0.removeFromSuperview()
            }
            newValue.map {
                let parallaxingView = parallaxableController.parallaxingView
                $0.translatesAutoresizingMaskIntoConstraints = false
                parallaxingView.insertSubview($0, at: 0)
                let topConstraint = $0.topAnchor.constraint(equalTo: parallaxingView.topAnchor)
                topConstraint.priority = .defaultHigh
                NSLayoutConstraint.activate([
                    topConstraint,
                    $0.leftAnchor.constraint(equalTo: parallaxingView.leftAnchor),
                    $0.rightAnchor.constraint(equalTo: parallaxingView.rightAnchor),
                    $0.bottomAnchor.constraint(equalTo: parallaxingView.bottomAnchor),
                ])
            }
        }
    }
    
    
    var overlayView: UIView?

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
    func setWrapperView<T: View>(_ view: T, for keyPath: ReferenceWritableKeyPath<_XCParallaxableViewCoordinator, UIView?>) {
        // For `EmptyView` we not need to create a wrapper view.
        if view is EmptyView {
            self[keyPath: keyPath] = nil
            return
        }
        // Try to reuse wrapper view for new content.
        if let wrapper = self[keyPath: keyPath] as? _XCParallaxableHostingWrapperView<T> {
            wrapper.replace(view)
            return
        }
        self[keyPath: keyPath] = _XCParallaxableHostingWrapperView(rootView: view, in: parallaxableController)
    }
    
    func apply(_ configuration: _XCParallaxableViewConfiguration) {
        // Apply configuration to parallaxable controller.
        contentOffsetObservers = configuration.contentOffsetObservers
        parallaxableController.isClipped = configuration.isClipped
        
        // Apply `SwiftUI.View` changes in to subview.
        configuration.handlers.values.forEach {
            $0(self)
        }
        
        // Make sure the backgroundView/foregroundView in the right view hierarchy.
        backgroundView.map(self.parallaxingView.sendSubviewToBack)
        overlayView.map(self.parallaxingView.bringSubviewToFront)
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
    
    /// Forward getter to the parallaxable controller.
    subscript<Value>(dynamicMember keyPath: KeyPath<XCParallaxableController, Value>) -> Value {
        get { parallaxableController[keyPath: keyPath] }
    }
    /// Forward setter/getter to the parallaxable controller.
    subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<XCParallaxableController, Value>) -> Value {
        get { parallaxableController[keyPath: keyPath] }
        set { parallaxableController[keyPath: keyPath] = newValue }
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didSelectItemAt index: Int) {
        // Notifiy selection the selected index is changes.
        guard let selection = selectedIndexObserver, selection.wrappedValue != index else {
            return
        }
        selection.wrappedValue = index
    }
    
    func parallaxableController(_ parallaxableController: XCParallaxableController, didChangeContentOffset contentOffset: CGPoint) {
        // Notifiy observers the content offset is changes.
        contentOffsetObservers.forEach {
            $0(contentOffset)
        }
    }
    
    init() {
        self.parallaxableController = .init()
        self.parallaxableController.delegate = self
    }
    
    private var reusableHostingControllers: [UIViewController]?
    
    private var contentOffsetObservers: [(CGPoint) -> ()] = []
    private var selectedIndexObserver: Binding<Int>?
}


// MARK: -


/// An hosting wrapper view.
///
/// The hosting views content and heights should changes frequently, direct using hosting view is a bad idea.
fileprivate class _XCParallaxableHostingWrapperView<Content: View>: UIView {
    
    
    required init(rootView: Content, in viewController: UIViewController) {
        super.init(frame: .zero)
        
        // Build all hosting view height constraints.
        self.viewController = viewController
        self.hostingViewHeight = (
            heightAnchor.constraint(lessThanOrEqualToConstant: 0),
            heightAnchor.constraint(equalToConstant: 0),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        )

        // Replace hosting view with the specified content.
        self.replace(rootView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        
        // Mark need to recalculate of the content size.
        hostingViewSize = nil
        viewController?.viewIfLoaded?.setNeedsLayout()
    }
    
    override var intrinsicContentSize: CGSize {
        // When the size is calculated, reuse.
        if let intrinsicContentSize = hostingViewSize {
            return intrinsicContentSize
        }
        
        // If the hosting view is not attach, ignore.
        guard let hostingView = hostingView else {
            return super.intrinsicContentSize
        }
        let width = viewController?.view.bounds.width ?? window?.bounds.width ?? bounds.width
        var height = CGFloat(0)

        // Calculate the min size of the hosting view content.
        let compressedSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let minSize = hostingView.sizeThatFits(compressedSize)
        if minSize.height != compressedSize.height {
            height = max(height, minSize.height)
        }

        // Calculate the max size of the hosting view content.
        let expandedSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let maxSize = hostingView.sizeThatFits(expandedSize)
        if maxSize.height != expandedSize.height {
            height = max(height, maxSize.height)
        }
        
        // The final hosting view height consists on multiple (le, eq, ge) height constraints.
        hostingViewHeight.map {
            // The equalTo(eq) constraint is calculate from the minSize and maxSize.
            $0.le.constant = maxSize.height
            $0.eq.constant = height
            $0.ge.constant = minSize.height
            // The equalTo(eq) constraint is activate only when the hosting view explicitly specified a size.
            $0.le.isActive = true
            $0.eq.isActive = minSize.height == maxSize.height
            $0.ge.isActive = true
        }
//        print("\(Content.self).\(#function) => \(minSize.height) - \(maxSize.height)")
        
        // When the equalTo(eq) constraint is not active, the constraint engine requrired evaluates
        // the final size based on the content size.
        let intrinsicContentSize = CGSize(width: UIView.noIntrinsicMetric, height: height)
        hostingViewSize = intrinsicContentSize
        return intrinsicContentSize
    }
    
    /// Replace hosting view with the specified content.
    func replace(_ content: Content)  {
        // Clean invaild hosting view.
        hostingView?.removeFromSuperview()
        
        // If `_UIHostingView` supports repleace we can using reusable version.
        let newValue = _XCParallaxableHostingView(rootView: content)
        newValue.frame = bounds
        newValue.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(newValue)
        hostingView = newValue

        invalidateIntrinsicContentSize()
    }
    
    private var hostingView: _XCParallaxableHostingView<Content>?
    private var hostingViewSize: CGSize?
    private var hostingViewHeight: (le: NSLayoutConstraint, eq: NSLayoutConstraint, ge: NSLayoutConstraint)?

    private weak var viewController: UIViewController?
}


// MARK: -


/// An `_UIHostingView` compatible view.
///
/// It is not recommended to use `_UIHostingView` directly.
/// Once Apple removed `_UIHostingView`, we should replace implementation with `UIHostingController`.
fileprivate class _XCParallaxableHostingView<Content: View>: _UIHostingView<Content> {
    
//    /// In the hosting view for the parallaxable controller can't using any `safeAreaInsets`.
//    /// But `_UIHostingView/UIHostingController` can't understand our intention,
//    /// To fix this issue we must let to always return to zero of `_UIHostingView` the `safeAreaInsets`.
//    override var safeAreaInsets: UIEdgeInsets {
//        return .zero
//    }
    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//
//        let newSize = self.sizeThatFits(UIView.layoutFittingCompressedSize)
//        if newSize != cachedSize {
//            cachedSize = newSize
////            print("\(Content.self).\(#function) => \(newSize)")
//        }
//    }
//
//    var cachedSize: CGSize?
//    override func didAddSubview(_ subview: UIView) {
//        super.didAddSubview(subview)
//        superview?.invalidateIntrinsicContentSize()
//    }
//
//    override func willRemoveSubview(_ subview: UIView) {
//        super.willRemoveSubview(subview)
//        superview?.invalidateIntrinsicContentSize()
//    }
}
