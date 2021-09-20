//
//  Parallaxable.swift
//  Parallaxable
//
//  Created by SAGESSE on 2020/12/30.
//

import UIKit


@objc public protocol XCParallaxable {
    
    /// Returns a scrollable  view that in the view hierarchy.
    ///
    /// The view should contains full-size of the view hierarchy, because the parallaxable controller
    /// will insert a parallax view into that scrollabe view.
    /// When the scrollable view set the wrong size it might cause the missing content of the parallax view.
    var scrollableView: UIScrollView? { get }
}


@objc public protocol XCParallaxableControllerDelegate {
    
    /// Tells the delegate that the item at the specified index was selected.
    ///
    /// - parameter parallaxableController: The parallaxable controller that is notifying you of the changes
    /// - parameter index: The index of that was selected.
    @objc optional func parallaxableController(_ parallaxableController: XCParallaxableController, didSelectItemAt index: Int)

    /// Tells the delegate when the content size was changes.
    /// - parameter parallaxableController: The parallaxable controller in which the content size changes
    /// - parameter contentSize: The new content size after the content changes
    @objc optional func parallaxableController(_ parallaxableController: XCParallaxableController, didChangeContentSize contentSize: CGSize)
    
    /// Tells the delegate when the user scrolls the content view within the receiver.
    /// - parameter parallaxableController: The parallaxable controller in which the scrolling occurred
    /// - parameter contentOffset: The new content offset after the content changes
    @objc optional func parallaxableController(_ parallaxableController: XCParallaxableController, didChangeContentOffset contentOffset: CGPoint)
}


/// An simple parallaxable controller.
@objc open class XCParallaxableController: UIViewController, UIScrollViewDelegate {

    /// The view that displays in the status bar or navigation bar content.
    ///
    /// When assigning a view to this property, the height of the view from:
    /// - Using `heightConstraint` when `constraint.priority` > 900.
    /// - Using `intrinsicContentSize.height` when `contentHuggingPriority` > 900.
    /// - Using `navigationBar.frame.height` when not match cases.
    @objc open var headerView: UIView? {
        get { parallaxing.headerView }
        set { parallaxing.headerView = newValue }
    }
    
    /// The view that displays below the header view.
    ///
    /// When assigning a view to this property, the view is auto self-height.
    @objc open var contentView: UIView? {
        get { parallaxing.contentView }
        set { parallaxing.contentView = newValue }
    }
    
    /// The view that displays below the content view.
    ///
    /// When assigning a view to this property, the view is auto self-height.
    /// unlike contentView the view is never exceeds headerView.
    @objc open var footerView: UIView? {
        get { parallaxing.footerView }
        set { parallaxing.footerView = newValue }
    }
    
    
    /// An array of the root view controllers displayed by the parallaxable interface.
    ///
    /// The default value of this property is nil.
    /// When configuring a parallaxable controller, you can use this property to specify the content for each page.
    /// The order of the view controllers in the array corresponds to the display order in the page.
    @objc open var viewControllers: [UIViewController]? {
        willSet {
            // Remake the item with view controller.
            let childViewController = newValue ?? []
            cachedItems = childViewController.enumerated().map { index, viewController in
                // Reuse item if needed.
                if let firstIndex = cachedItems.firstIndex(where: { $0.viewController == viewController }) {
                    let item = cachedItems[firstIndex]
                    cachedItems.remove(at: firstIndex)
                    return item
                }
                return XCParallaxableItem(viewController, parallaxable: self)
            }
            // Update all items to components.
            pagging.setItems(cachedItems, animated: false)
            parallaxing.setItems(cachedItems, animated: false)
        }
    }
    
    /// The extra distance that the parallaxing view is inset from the scrollable view edges.
    @objc open var contentInset: UIEdgeInsets {
        get { parallaxing.contentInset }
        set {
            performWithoutContentChanges {
                parallaxing.contentInset = newValue
                parallaxing.containerView.layoutIfNeeded()
                parallaxing.layoutSubviews()
            }
        }
    }

    /// The size of the parallaxable controller content.
    @objc open var contentSize: CGSize {
        return cachedContentSize
    }

    /// The point at which the origin of the parallaxing view is offset from the origin of the parallaxable controller.
    @objc open var contentOffset: CGPoint {
        get { cachedContentOffset }
        set {
            updateContentOffset(newValue) {
                $0.contentOffset = $1
            }
        }
    }
    
    @objc open func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        updateContentOffset(contentOffset) {
            $0.setContentOffset($1, animated: animated)
        }
    }
    
    
    /// The index of the view controller associated with the currently selected page item.
    @objc open var selectedIndex: Int {
        get { pagging.selectedIndex }
        set { setSelectedIndex(newValue, animated: false) }
    }
    
    /// The view controller associated with the currently selected page item.
    @objc open var selectedViewController: UIViewController? {
        return pagging.selectedItem?.viewController
    }
    
    /// Update the index of the view controller associated with the new selected page item.
    /// - parameter selectedIndex: the index of the view controller associated with the new selected page item.
    /// - parameter animated: true to animate the transition at a constant velocity to the new index, false to make the transition immediate.
    @objc open func setSelectedIndex(_ selectedIndex: Int, animated: Bool) {
        // When content index not any changes or can't found view controller, ignore.
        guard pagging.selectedIndex != selectedIndex, selectedIndex < pagging.items.count else {
            return
        }
        performWithoutContentChanges {
            pagging.setSelectedIndex(selectedIndex, animated: animated)
        }
    }
    
    
    /// A Boolean value that determines whether content view are confined to the bounds of the parallaxing view.
    @objc open var isClipped: Bool {
        get { parallaxing.isClipped }
        set { parallaxing.isClipped = newValue }
    }

    
    /// The pagging container view associated with this controller.
    @objc open var paggingView: UIScrollView {
        return pagging.containerView
    }
    
    /// The parallaxing container view associated with this controller.
    @objc open var parallaxingView: UIView {
        return parallaxing.containerView
    }
    
    
    /// The parallaxable controller’s delegate object.
    @objc open weak var delegate: XCParallaxableControllerDelegate?
    
    
    open override func loadView() {
        super.loadView()
        
        // Must using WrapperView to base view, because when the `scrollableView.contentInset`
        // is nonzero, the `paggingView.frameLayoutGuide` is unexpected.
        view = UIView.dynamicInit(name: "XCParallaxableWrapperView", frame: UIScreen.main.bounds)
        
        // The containerView needs to using all area and automatically adapt to changes.
        paggingView.delegate = self
        paggingView.frame = view.bounds
        paggingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(paggingView)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        // Continue forwarding appearance methods and process other handler.
        super.viewDidAppear(animated)

        // When the view controller is already displayed in the view hierarchy,
        // UIKit can't automatically forwarding to appearance methods of
        // child view controller the any opereations, so we must manually forwarding.
        pagging.shouldForwardAppearanceMethods = true
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        // In default UIKit will automatically forwarding appearance methods, but
        // UIKit can't forwarding at same time of multiple view controllers case,
        // so we must to cancel scroll restore to single view controller.
        pagging.setSelectedIndex(selectedIndex, animated: false)
        pagging.shouldForwardAppearanceMethods = false
        
        // Continue forwarding appearance methods and process other handler.
        super.viewWillDisappear(animated)
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // When the bounds not any changes, ignore.
        guard !isLockedConentChanges, view.bounds.size != cachedSize else {
            return
        }
        cachedSize = view.bounds.size

        // Update all subview layout when the bounds.size is changes.
        performWithoutContentChangesIfNeeded {
            updateHorizontalContentOffsetIfNeeded()
            updateVerticalContentOffsetIfNeeded()
        }
    }
    
    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        // Synchronize into parallaxing.
        performWithoutContentChangesIfNeeded {
            parallaxing.itemSafeAreaInsets.top = view.safeAreaInsets.top - additionalSafeAreaInsets.top
        }
    }
    
    
    open override var childForStatusBarStyle: UIViewController? {
        return selectedViewController
    }
    
    open override var childForStatusBarHidden: UIViewController? {
        return selectedViewController
    }
    
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        return selectedViewController
    }
    
    open override var childViewControllerForPointerLock: UIViewController? {
        return selectedViewController
    }
    
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        performWithoutContentChangesIfNeeded {
            updateVerticalContentOffsetIfNeeded()
        }
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        performWithoutContentChangesIfNeeded {
            updateHorizontalContentOffsetIfNeeded()
        }
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        performWithoutContentChangesIfNeeded {
            endScrollAnimation()
        }
    }
    
    
    @objc fileprivate func contentScrollView() -> UIScrollView? {
        return (selectedViewController as AnyObject?)?.contentScrollView()
    }
    
    
    /// Perform something should not trigger the content changes of prevents recursive calls version.
    fileprivate func performWithoutContentChangesIfNeeded(_ actions: () -> Void) {
        // When the content offset changes is loacked, ignore.
        guard !isLockedConentChanges else {
            return
        }
        performWithoutContentChanges(actions)
    }
    /// Perform something should not trigger the content changes.
    fileprivate func performWithoutContentChanges(_ actions: () -> Void) {
        // Because this method is only executed on the main thread, there is no need to lock it.
        let oldValue = isLockedConentChanges
        let oldMergeFlags = isMergeChanges
        isLockedConentChanges = true
        isMergeChanges = true
        actions()
        isLockedConentChanges = oldValue
        // Each time need to check whether handle the change events.
        isMergeChanges = oldMergeFlags
        updateContentChangesIfNeeded()
    }
    
    /// Start the scroll animation if needed.
    fileprivate func beginScrollAnimation(_ animated: Bool) {
        // When locked staus not any changes, ignore.
        guard isLockedIndexChanges != animated else {
            return
        }
        endScrollAnimation()
        isLockedIndexChanges = animated
    }
    /// Stop the scroll animation.
    fileprivate func endScrollAnimation() {
        // When locked staus not any changes, ignore.
        guard isLockedIndexChanges != false else {
            return
        }
        isLockedIndexChanges = false
        // The selected index maybe changed and needs to be immediate notice.
        setNeedsUpdateSelected()
    }
    
    /// Gets vertical scrollable item with content offset.
    fileprivate func scrollableItem(at offset: CGPoint) -> XCParallaxableItem? {
        // Only item that are fully displayed can be vertical scrollable,
        guard let item = pagging.selectedItem, fmod(offset.x, pagging.frame.width) == 0 else {
            return nil
        }
        return item
    }
    
    /// Mark selected index is changed.
    fileprivate func setNeedsUpdateSelected() {
        changes.insert(.selectedIndex)
        updateContentChangesIfNeeded()
    }
    
    /// Mark content size is changed.
    fileprivate func setNeedsUpdateContentSize() {
        changes.insert(.contentSize)
        updateContentChangesIfNeeded()
    }
    
    /// Mark content offset is changed.
    fileprivate func setNeedsUpdateContentOffset() {
        changes.insert(.contentOffset)
        updateContentChangesIfNeeded()
    }
    
    /// Apply all changes to this.
    fileprivate func updateContentChangesIfNeeded() {
        // When enabled merging all changes, will be called again later.
        guard !isMergeChanges && !changes.isEmpty else {
            return
        }
        
        // Process the conent size change event.
        if let _ = changes.remove(.contentSize) {
            // Quickly calculate the final result.
            cachedContentSize = .init(width: pagging.contentSize.width, height: parallaxing.contentSize.height)
            
            // Tells the user the current size is changed.
            delegate?.parallaxableController?(self, didChangeContentSize: cachedContentSize)
        }
        
        // Process the conent offset change event.
        if let _ = changes.remove(.contentOffset) {
            // Quickly calculate the final result.
            cachedContentOffset = .init(x: pagging.contentOffset.x, y: parallaxing.contentOffset.y)
            
            // Tells the user the current offset is changed.
            delegate?.parallaxableController?(self, didChangeContentOffset: cachedContentOffset)
        }
        
        // Process the selected index change event.
        if let _ = changes.remove(.selectedIndex), !isLockedIndexChanges {
            // When the visabled index is changes, update the status bar.
            setNeedsStatusBarAppearanceUpdate()
            
            // Tells the user the current page is changed.
            delegate?.parallaxableController?(self, didSelectItemAt: selectedIndex)
        }
    }
    
    fileprivate func updateContentOffset(_ newValue: CGPoint, updater: (UIScrollView, CGPoint) -> ()) {
        performWithoutContentChanges {
            // Second synchronization when horizontal content changes.
            let dx = newValue.x - cachedContentOffset.x
            if dx != 0 {
                var contentOffset = paggingView.contentOffset
                contentOffset.x += dx
                updater(paggingView, contentOffset)
                updateHorizontalContentOffsetIfNeeded()
            }
            // First synchronization when vertical content changes.
            let dy = newValue.y - cachedContentOffset.y
            if dy != 0, let scrollView = pagging.selectedItem?.scrollViewIfLoaded {
                var contentOffset = scrollView.contentOffset
                contentOffset.y = newValue.y - scrollView.adjustedContentInset.top
                updater(scrollView, contentOffset)
                updateVerticalContentOffsetIfNeeded()
            }
        }
    }
    
    /// The horizontal content offset is changed.
    fileprivate func updateHorizontalContentOffsetIfNeeded() {
        performWithoutContentChanges {
            pagging.layoutSubviews()
            pagging.setSelectedIndex(pagging.contentOffset, animated: false)
            parallaxing.move(to: scrollableItem(at: pagging.contentOffset))
        }
    }
    /// The vertical content offset is changed.
    fileprivate func updateVerticalContentOffsetIfNeeded() {
        performWithoutContentChanges {
            parallaxing.layoutSubviews()
            parallaxing.setContentOffset(pagging.selectedItem, animated: false)
        }
    }
    
    private var changes: XCParallaxableChangeEvent = []
    
    private var isMergeChanges: Bool = false
    private var isLockedConentChanges: Bool = false
    private var isLockedParallaxingView: Bool = true
    private var isLockedIndexChanges: Bool = false
    
    private var isAutomaticallyLinking: Bool = false
    
    private var cachedSize: CGSize?
    private var cachedVisibleSize: CGSize?
    private var cachedVisibleMargins: UIEdgeInsets?
    
    private var cachedContentOffset: CGPoint = .zero
    private var cachedContentSize: CGSize = .zero
    
    private var cachedItems: [XCParallaxableItem] = []
        
    fileprivate lazy var pagging: XCParallaxablePagging = .init(self)
    fileprivate lazy var parallaxing: XCParallaxableParallaxing = .init(self)
}


// MARK: -


/// An managed item with added to view controller of parallaxable controller.
fileprivate final class XCParallaxableItem: Equatable {
    
    /// The view controller that the managed.
    let viewController: UIViewController
    
    /// The view that the controller manages.
    var view: UIView {
        // When the content is load view, ignore.
        guard !isViewLoaded else {
            return viewController.view
        }
        // Force load view of the view contorller.
        isViewLoaded = true
        loadView()
        updateScrollViewIfNeeded()
        return viewController.view
    }
    /// The view controller’s view, or nil if the view is not yet loaded.
    var viewIfLoaded: UIView? {
        // When the view not display, ignore.
        guard isViewLoaded else {
            return nil
        }
        return viewController.viewIfLoaded
    }
    
    /// The scrollable view that in the controller view hierarchy.
    var scrollView: UIScrollView?
    /// The scrollable view that in the controller view hierarchy, or nil if the view is not yet loaded.
    var scrollViewIfLoaded: UIScrollView? {
        // When the view not display, ignore.
        guard isViewLoaded, view.superview != nil else {
            return nil
        }
        return scrollView
    }
    
    /// A Boolean value indicating whether the view is currently loaded into memory.
    var isViewLoaded: Bool = false

    /// The frame rectangle, same the controller.view.frame, setter are delayed when view not loaded.
    var frame: CGRect = .zero {
        willSet {
            // When is already in view hierarchy, must a real-time call frame.
            guard let view = viewIfLoaded else {
                return
            }
            // Update the frame maybe cause the content offset to changes.
            performWithoutContentChanges {
                view.frame = newValue
            }
        }
    }
    
    /// Move the view into the view hierarchy.
    func move(to newSuperview: UIView) {
        // When the superview is not any changes, ignore.
        let isFirstLoad = !isViewLoaded
        guard newSuperview !== view.superview else {
            return
        }
        // Always insert at the bottom to prevent overlayed parallaxing view.
        newSuperview.insertSubview(view, at: 0)
        
        // Must ensure the layout is valid in the before synchronizing changes,
        // Otherwise cause the synchronized changes invaild.
        parallaxable.performWithoutContentChanges {
            if isFirstLoad {
                view.layoutIfNeeded()
            }
        }
        
        // The each time move the superview maybe cause scrollable view will changes.
        parallaxable.performWithoutContentChanges {
            updateScrollViewIfNeeded()
            updateContentOffset(parallaxable.contentOffset)
        }
    }
    
    /// Prepare the view that the controller manages.
    func loadView() {
        // Force the view to load and update the view frame.
        viewController.view.frame = frame
        viewController.view.autoresizingMask = []
    }
    
    /// Tells a view controller its will appear.
    func willAppear(_ animated: Bool) {
        viewController.beginAppearanceTransition(true, animated: animated)
    }
    /// Tells a view controller its did appear.
    func didAppear(_ animated: Bool) {
        viewController.endAppearanceTransition()
    }
    
    /// Tells a view controller its will disappear.
    func willDisappear(_ animated: Bool) {
        viewController.beginAppearanceTransition(false, animated: animated)
    }
    /// Tells a view controller its did disappear.
    func didDisappear(_ animated: Bool) {
        viewController.endAppearanceTransition()
    }
    
    /// Add to observers of the scrollable view.
    func addObservers() {
        guard !isObsrvering else {
            return
        }
        scrollView?.addObserver(parallaxable, forKeyPath: "contentOffset", options: .old, context: nil)
        isObsrvering = true
    }
    /// Remove to observers of the scrollable view.
    func removeObservers() {
        guard isObsrvering else {
            return
        }
        scrollView?.removeObserver(parallaxable, forKeyPath: "contentOffset")
        isObsrvering = false
    }

    /// Update the content offset of the scrollable view with new content offset.
    func updateContentOffset(_ newValue: CGPoint) {
        // When the scroll view is not found, ignore.
        guard let scrollView = scrollView else {
            return
        }
        let top = scrollView.adjustedContentInset.top
        
        // When the content is displaying, the scroll view must pinned at the top.
        var contentOffsetY = scrollView.contentOffset.y + top
        if newValue.y < parallaxable.contentSize.height {
            contentOffsetY = 0
        }
        
        // When the content offset not any changes, ignore.
        let newContentOffsetY = max(newValue.y, contentOffsetY) - top
        guard newContentOffsetY != scrollView.contentOffset.y else {
            return
        }
        scrollView.contentOffset.y = newContentOffsetY
    }
    /// Update the scroll decorations inset of scrollable view with content offset.
    func updateScrollDecorationTop(_ newValue: CGFloat) {
        // When the newValue not any changes or not attach a scrollable view, ignore.
        let fixedValue = max(newValue, 0)
        guard adjustedScrollDecorationsTop != fixedValue, let tableView = scrollView as? UITableView else {
            return
        }
        // When the first set scroll decorations to nonzero, try to enable hotfix.
        if fixedValue != 0 && adjustedScrollDecorationsTop == 0 {
            UITableView._paraxable_hotfixUsedCount += 1
        }
        // When the last set scroll decorations to zero, try to disable hotfix.
        if fixedValue == 0 && adjustedScrollDecorationsTop != 0 {
            UITableView._paraxable_hotfixUsedCount -= 1
        }
        adjustedScrollDecorationsTop = fixedValue
        objc_setAssociatedObject(tableView, &UITableView._paraxable_hotfixUsedCount, fixedValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// Update the scroll indicator inset of scrollable view with content offset.
    func updateScrollIndicatorTop(_ newValue: CGFloat) {
        // When the newValue not any changes or not attach a scrollable view, ignore.
        guard adjustedScrollIndicatorTop != newValue, let scrollView = scrollView else {
            return
        }
        // Fix indicator insets wrong due to content offset.
        var verticalScrollIndicatorTop = scrollView.verticalScrollIndicatorInsets.top
        verticalScrollIndicatorTop -= newValue - adjustedScrollIndicatorTop
        guard verticalScrollIndicatorTop >= 0 else {
            return
        }
        adjustedScrollIndicatorTop = newValue
        scrollView.verticalScrollIndicatorInsets.top = verticalScrollIndicatorTop
    }
    /// Update the new scrollable view.
    func updateScrollViewIfNeeded() {
        // When the view controller is not loaded, ignore.
        guard isViewLoaded else {
            return
        }
        // When the scrollable view not any changes, ignore.
        let newValue = scrollableView()
        guard scrollView !== newValue else {
            return
        }
        updateScrollView(newValue)
    }
    /// Update the new scrollable view.
    func updateScrollView(_ newValue: UIScrollView?) {
        let needRestoreObservering = isObsrvering
        
        // Revert attached scrollable view to original state.
        scrollView.map { _ in
            removeObservers()
            updateScrollDecorationTop(0)
            updateScrollIndicatorTop(0)
        }
        
        scrollView = newValue
        
        // Apply current all changes to scrollabe view
        newValue.map { _ in
            let contentOffset = parallaxable.parallaxing.contentOffset
            updateScrollDecorationTop(contentOffset.y)
            updateScrollIndicatorTop(contentOffset.y)
            if needRestoreObservering {
                addObservers()
            }
        }
    }
    
    /// Gets the scrollable view that in the view hierarchy.
    func scrollableView() -> UIScrollView? {
        switch viewController {
        case let source as XCParallaxable:
            // When the controller implements the `XCParallaxable`, that get the
            // scrollable view can be faster and securely.
            return source.scrollableView
            
        case let source as UITableViewController:
            return source.tableView
            
        case let source as UICollectionViewController:
            return source.collectionView
            
        case let source as AnyObject where hasContentScrollView:
            return source.contentScrollView()
            
        default:
            return nil
        }
    }
    
    /// Perform something should not trigger the content changes event.
    func performWithoutContentChanges(_ actions: () -> ()) {
        // When the scroll view is not found, ignore.
        guard let scrollView = scrollViewIfLoaded else {
            actions()
            return
        }
        // When the update actions will cause content offset changes,
        // Must restore origin content offset after updated.
        let oldContentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        
        actions()
        
        // Restore the content offset changes is required only when the content is fully displayed,
        // otherwise incorrect behavior maybe occur.
        guard oldContentOffsetY <= 0 else {
            return
        }
        
        // Restore the content offset changes.
        scrollView.contentOffset.y = oldContentOffsetY - scrollView.adjustedContentInset.top
    }
    
    /// Create a managed item with a view controller.
    init(_ viewController: UIViewController, parallaxable: XCParallaxableController) {
        // The association must bind at init.
        self.parallaxable = parallaxable
        self.viewController = viewController
        
        // When the view controller is load, direct load view info.
        if self.viewController.isViewLoaded {
            _ = self.view
        }
    }
    
    deinit {
        self.updateScrollView(nil)
    }
    
    private var adjustedScrollIndicatorTop: CGFloat = 0
    private var adjustedScrollDecorationsTop: CGFloat = 0

    private var isObsrvering: Bool = false
    
    private let hasContentScrollView = UIViewController.instancesRespond(to: #selector(AnyObject.contentScrollView))
    
    private unowned(unsafe) let parallaxable: XCParallaxableController
}

fileprivate extension XCParallaxableItem {
    
    /// Returns a Boolean value indicating whether two values are equal.
    static func == (lhs: XCParallaxableItem, rhs: XCParallaxableItem) -> Bool {
        return rhs.viewController == rhs.viewController
    }
}


// MARK: -


@dynamicMemberLookup
fileprivate final class XCParallaxablePagging<Item, ContainerView> where Item: XCParallaxableItem, ContainerView: UIScrollView {
    
    /// When the child view controller changes, the lifecycle is automatically managed
    var shouldForwardAppearanceMethods: Bool = false
    
    /// The container of displaying content.
    let containerView: ContainerView
    
    /// The all managed items with added to view controller of parallaxable controller.
    var items: [Item] = []
    /// Update the all managed items with added to view controller of parallaxable controller.
    func setItems(_ newValue: [Item], animated: Bool) {
        // Remove all expired items.
        items.filter { !newValue.contains($0) }.forEach {
            // Don't remove view when view controller view is not loaded.
            $0.viewController.viewIfLoaded?.removeFromSuperview()
            $0.viewController.removeFromParent()
        }
        // When the view has been loaded, recalculate the content size.
        items = newValue
        containerView.setNeedsLayout()
        parallaxable.setNeedsStatusBarAppearanceUpdate()
        cachedSize = nil
    }

    /// The selected index for selected item.
    var selectedIndex: Int {
        get { visabledIndex }
        set {
            // When the newValue not any changes, ignore.
            guard newValue != visabledIndex, newValue < items.count, newValue >= 0 else {
                return
            }
            visabledIndex = newValue
            parallaxable.setNeedsUpdateSelected()
        }
    }
    /// Update selected item with index.
    func setSelectedIndex(_ newValue: Int, animated: Bool) {
        // When the view is not loaded, wait until view did load.
        guard parallaxable.isViewLoaded else {
            visabledIndex = newValue
            return
        }
        // When the index can't found content, ignore.
        guard newValue < items.count else {
            return
        }
        // Update the content offset for selected index.
        var newContentOffset = containerView.contentOffset
        newContentOffset.x = containerView.frame.width * .init(newValue)
        parallaxable.beginScrollAnimation(animated)
        containerView.setContentOffset(newContentOffset, animated: animated)
        
        // When setContentOffset with a animation, this a progressive process,
        // using contentOffset to gets the real-time offset.
        setSelectedIndex(containerView.contentOffset, animated: false)
    }
    /// Update selected content with content offset.
    func setSelectedIndex(_ newValue: CGPoint, animated: Bool) {
        // When the offset not any changes, ignore.
        guard !items.isEmpty, cachedOffset?.x != newValue.x else {
            return
        }
        // Update visbles view controllers.
        layoutSubviews(for: newValue)
        
        // Update the visable item for content offset.
        selectedIndex = .init(round(newValue.x / containerView.frame.width))
    }
    
    /// The selected content of user.
    var selectedItem: Item? {
        return item(at: selectedIndex)
    }

    /// Forward getter to the container.
    subscript<Value>(dynamicMember keyPath: KeyPath<ContainerView, Value>) -> Value {
        get { containerView[keyPath: keyPath] }
    }
    /// Forward setter/getter to the container.
    subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<ContainerView, Value>) -> Value {
        get { containerView[keyPath: keyPath] }
        set { containerView[keyPath: keyPath] = newValue }
    }
    
    /// Update the subviews layout of contents.
    func layoutSubviews() {
        // When the frame is not any chagnes, ignore.
        let size = containerView.frame.size
        guard size.width != cachedSize?.width else {
            return
        }
        cachedSize = size
        items.enumerated().forEach {
            $1.frame = CGRect(x: size.width * .init($0), y: 0, width: size.width, height: size.height)
        }
        // When the content size not any chagnes, ignore.
        let newContentSize = CGSize(width: size.width * .init(items.count), height: 0)
        guard newContentSize.width != containerView.contentSize.width else {
            return
        }
        containerView.contentSize = newContentSize
        parallaxable.setNeedsUpdateContentSize()
        
        // When the content size is changes, restore the content offset.
        setSelectedIndex(selectedIndex, animated: false)
    }
    /// Update the subviews layout of visable rect.
    func layoutSubviews(for offset: CGPoint) {
        // When the contens is empty, ignore.
        let count = items.count
        guard count != 0 else {
            return
        }
        // Cached the last offset for reduces the invalid calls.
        cachedOffset = offset
        parallaxable.setNeedsUpdateContentOffset()
        
        // Computes the currently visible controller.
        let newTransition = offset.x / max(containerView.frame.width, 1)
        let newValue = min(Int(trunc(newTransition)), count - 1) ... min(Int(ceil(newTransition)), count - 1)
        
        // When the range not any changes, ignore.
        guard visibledIndexes != newValue else {
            return
        }
        // Calculate the add or remove of the view controller.
        let newItems = newValue.filter { !(visibledIndexes?.contains($0) ?? false) }
        let removeItems = visibledIndexes?.filter { !newValue.contains($0) } ?? []
        let currentItems = visibledIndexes?.filter { !appearing.contains($0) && !disappearing.contains($0) } ?? []
        
        // Update current visable indexs.
        visibledIndexes = newValue
        
        // When has a new item, content will add to appearing queue.
        for index in newItems {
            appearing.append(index)
            forwardItem(at: index)?.willAppear(false)
        }
        // Pages start disappear.
        for index in currentItems {
            disappearing.append(index)
            forwardItem(at: index)?.willDisappear(false)
        }
        
        // Remove the invisible controller.
        for index in removeItems {
            item(at: index).map {
                $0.viewController.willMove(toParent: nil)
                $0.viewController.viewIfLoaded?.removeFromSuperview()
                $0.viewController.setNeedsStatusBarAppearanceUpdate()
                $0.viewController.removeFromParent()
            }
        }
        // Add visable view contorller.
        for index in newItems {
            item(at: index).map {
                parallaxable.addChild($0.viewController)
                $0.move(to: containerView)
                $0.viewController.didMove(toParent: parallaxable)
                $0.viewController.setNeedsStatusBarAppearanceUpdate()
            }
        }
        
        // Pages end appear.
        for index in newValue where newValue.count == 1 {
            disappearing.firstIndex(of: index).map {
                disappearing.remove(at: $0)
                forwardItem(at: index)?.willAppear(false)
                forwardItem(at: index)?.didAppear(false)
            }
            appearing.firstIndex(of: index).map {
                appearing.remove(at: $0)
                forwardItem(at: index)?.didAppear(false)
            }
        }
        // Pages end disappear.
        for index in removeItems {
            appearing.firstIndex(of: index).map {
                appearing.remove(at: $0)
                forwardItem(at: index)?.willDisappear(false)
                forwardItem(at: index)?.didDisappear(false)
            }
            disappearing.firstIndex(of: index).map {
                disappearing.remove(at: $0)
                forwardItem(at: index)?.didDisappear(false)
            }
        }
    }
    
    /// Gets the content at index.
    private func item(at index: Int) -> Item? {
        // When index is over boundary, ignore.
        guard index < items.count else {
            return nil
        }
        return items[index]
    }
    /// Get the appearancable content at index.
    private func forwardItem(at index: Int) -> Item? {
        // When automatic forwarding for child view controller is off, ignore.
        guard shouldForwardAppearanceMethods else {
            return nil
        }
        return item(at: index)
    }
    
    /// Create a custom pagging manager.
    init(_ parallaxable: XCParallaxableController) {
        // The association must bind at init.
        self.parallaxable = parallaxable
        
        // Configure the pagging view.
        self.containerView = ContainerView.dynamicInit(name: "XCParallaxableContainerView", frame: .zero)
        self.containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.containerView.isOpaque = true
        self.containerView.isPagingEnabled = true
        self.containerView.isDirectionalLockEnabled = true
        self.containerView.scrollsToTop = false
        self.containerView.clipsToBounds = true
        self.containerView.showsVerticalScrollIndicator = false
        self.containerView.showsHorizontalScrollIndicator = false
        
        // In the iPhone X of landscape mode, this is the wrong behavior.
        self.containerView.contentInsetAdjustmentBehavior = .never
    }
    
    private var appearing: [Int] = []
    private var disappearing: [Int] = []
    
    private var cachedSize: CGSize?
    private var cachedOffset: CGPoint?
    
    private var visabledIndex: Int = 0
    private var visibledIndexes: ClosedRange<Int>?
    
    private unowned(unsafe) let parallaxable: XCParallaxableController
}


// MARK: -


@dynamicMemberLookup
fileprivate final class XCParallaxableParallaxing<Item, ContainerView> where Item: XCParallaxableItem, ContainerView: UIView {
    
    /// The container of displaying content.
    let containerView: ContainerView
    
    /// The header view of parallaxing view.
    var headerView: UIView? {
        willSet {
            updateSubview(newValue, from: headerView, layoutGuide: &topLayoutGuide)
        }
    }
    /// The contnet view of parallaxing view.
    var contentView: UIView? {
        willSet {
            contentView?.mask = nil
            updateSubview(newValue, from: contentView, layoutGuide: &contentLayoutGuide)
            newValue.map {
                containerView.sendSubviewToBack($0)
                $0.mask = buildMaskView(isClipped)
            }
        }
    }
    /// The footer view of parallaxing view.
    var footerView: UIView? {
        willSet {
            updateSubview(newValue, from: footerView, layoutGuide: &bottomLayoutGuide)
        }
    }

    /// The all managed items with added to view controller of parallaxable controller.
    var items: [Item] = []
    /// Update the all managed items with added to view controller of parallaxable controller.
    func setItems(_ newValue: [Item], animated: Bool) {
        items = newValue
        items.forEach {
            $0.updateScrollViewIfNeeded()
        }
    }
    
    /// A Boolean value that determines whether content view are confined to the bounds of the parallaxing view.
    var isClipped: Bool = false {
        willSet {
            contentView?.mask = buildMaskView(newValue)
        }
    }
    
    /// The insets that you use to determine the safe area for parallaxing view.
    var itemSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            // When the safeAreaInsets is changes, must synchronize to all contents.
            guard itemSafeAreaInsets != oldValue else {
                return
            }
            navigationLayoutConstraint.constant = itemSafeAreaInsets.top
        }
    }
    /// The extra distance that the parallaxing view is inset from the scrollable view edges.
    var itemContentInset: UIEdgeInsets = .zero {
        didSet {
            // When the contentInset not any changes, ignore.
            guard itemContentInset != oldValue else {
                return
            }
            parallaxable.additionalSafeAreaInsets.top = itemContentInset.top - itemSafeAreaInsets.top
        }
    }
    
    /// The extra distance that the parallaxing view is inset from the scrollable view edges.
    var contentInset: UIEdgeInsets {
        get { contentLayoutGuide.contentInset }
        set { contentLayoutGuide.contentInset = newValue }
    }
    
    /// The size of scrollable content of parallaxing view.
    var contentSize: CGSize = .zero
    /// The point at which the origin of the parallaxing view is offset from the origin of the parallaxable controller.
    var contentOffset: CGPoint = .zero {
        willSet {
            // When te content offset not any changes, ignore.
            guard newValue != contentOffset else {
                return
            }
            cachedMaskView?.transform = .init(translationX: 0, y: newValue.y)
            offsetLayoutConstraint.constant = -newValue.y
            performWithoutContentChanges {
                $0.updateScrollDecorationTop(newValue.y)
                $0.updateScrollIndicatorTop(newValue.y)
            }
        }
    }
    /// Sets the offset from the origin that corresponds of the parallaxing view from the origin of the parallaxable controller.
    func setContentOffset(_ newValue: Item?, animated: Bool) {
        // When the current scroll view not found, ignore.
        guard let scrollView = newValue?.scrollViewIfLoaded else {
            return
        }
        let newValue = min(scrollView.contentOffset.y + scrollView.adjustedContentInset.top, contentSize.height)
        guard newValue != contentOffset.y else {
            // When content offset changes, must need to bring the container view in the front.
            bringSubviewToFrontIfNeeded()
            return
        }
        contentOffset.y = newValue
        parallaxable.setNeedsUpdateContentOffset()
    }

    /// A Boolean value that indicates whether has begun should render.
    var shouldRenderInHierarchy: Bool {
        return headerView != nil || contentView != nil || footerView != nil
    }
    
    /// Gets the container view index from superview.
    var actualViewIndex: Int {
        guard let superview = containerView.superview else {
            return 0
        }
        let subviews = superview.subviews
        guard let index = subviews.lastIndex(of: containerView) else {
            return 0
        }
        return subviews.count - index - 1
    }
    
    /// Perform something should not trigger the content changes.
    private func performWithoutContentChanges(_ actions: (Item) -> Void) {
        parallaxable.performWithoutContentChanges {
            items.forEach(actions)
        }
    }
    
    /// Forward getter to the container.
    subscript<Value>(dynamicMember keyPath: KeyPath<ContainerView, Value>) -> Value {
        get { containerView[keyPath: keyPath] }
    }
    /// Forward getter to the container.
    subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<ContainerView, Value>) -> Value {
        get { containerView[keyPath: keyPath] }
        set { containerView[keyPath: keyPath] = newValue }
    }
    
    /// Move item to scrollable view
    func move(to item: Item?) {
        // When the contanier is not ready, ignore.
        guard shouldRenderInHierarchy else {
            // TODO: removeFromSuperview and cache
            activedItem = nil
            return
        }
        // When the scrollable view not found, revert to the superview.
        let newSuperview = item?.scrollViewIfLoaded ?? parallaxable.paggingView
        guard newSuperview !== containerView.superview else {
            return
        }
        // Remove superview will clean all related constraints.
        containerView.removeFromSuperview()
        newSuperview.addSubview(containerView)
        layoutSubviews()
        
        // Update the observers
        activedItem = item
        cachedLayerIndex = actualViewIndex

        // Always pinned the container to superview.
        NSLayoutConstraint.activate(
            [
                containerView.topAnchor.constraint(equalTo: parallaxable.view.topAnchor),
                containerView.leftAnchor.constraint(equalTo: parallaxable.view.leftAnchor),
                containerView.rightAnchor.constraint(equalTo: parallaxable.view.rightAnchor),
            ]
        )
    }
    
    /// Update the subviews layout of contents.
    func layoutSubviews() {
        // When container height is zero, which means that containerView is not initialize.
        // we just simply calculate the actual contentSize.
        let newContainerHeight = containerView.frame.height
        guard newContainerHeight != cachedContainerHeight || newContainerHeight == 0 else {
            return
        }
        cachedContainerHeight = newContainerHeight

        // Calculate all the layoutGuides frame information.
        let topLayoutFrame = topLayoutGuide.layoutFrame
        let bottomLayoutFrame = bottomLayoutGuide.layoutFrame
        let contentLayoutFrame = contentLayoutGuide.layoutFrame
        
        // When the content inset not any changes, ignore.
        let top = topLayoutFrame.height + contentLayoutFrame.height + bottomLayoutFrame.height
        guard top != itemContentInset.top else {
            return
        }
        itemContentInset.top = top

        // When the content size not any change, ignore.
        let newConetntHeight = contentLayoutFrame.height
        guard newConetntHeight != contentSize.height else {
            return
        }
        contentSize.height = newConetntHeight
        parallaxable.setNeedsUpdateContentSize()
    }
    
    func bringSubviewToFrontIfNeeded() {
        // When the layer index not any changes, ignore.
        guard cachedLayerIndex != actualViewIndex else {
            return
        }
        // Recalculate view index when bring to front.
        containerView.superview?.bringSubviewToFront(containerView)
        cachedLayerIndex = actualViewIndex
    }
    
    /// Update the subview of the layout guide.
    private func updateSubview(_ newValue: UIView?, from oldValue: UIView?, layoutGuide: inout XCParallaxableInsetLayoutGuide) {
        // When the view not any changes, ignore.
        guard newValue !== oldValue else {
            return
        }
        
        // Must remove the old view before add a new view.
        oldValue?.removeFromSuperview()
        
        // When the new value is empty, ignore.
        guard let newValue = newValue else {
            return
        }
        
        // Remove from superview to clean all related constraints.
        newValue.removeFromSuperview()
        newValue.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(newValue)
        containerView.addConstraints(layoutGuide.constraints(insetTo: newValue))
    }
    
    /// Update the make view.
    private func buildMaskView(_ isClipped: Bool) -> UIView? {
        // When clipped is disable, clear the mask view.
        if !isClipped {
            cachedMaskView = nil
            return nil
        }
        // When mask is hit, reuse it.
        guard cachedMaskView == nil else {
            return cachedMaskView
        }
        // Build a new mask view.
        let width = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let view = UIView(frame: .init(x: 0, y: 0, width: width, height: width))
        view.backgroundColor = .black
        view.transform = .init(translationX: 0, y: contentOffset.y)
        cachedMaskView = view
        return view
    }
    
    /// Create a custom pagging manager.
    init(_ parallaxable: XCParallaxableController) {
        // The association must bind at init.
        self.parallaxable = parallaxable
        
        self.containerView = ContainerView.dynamicInit(name: "XCParallaxablePresentedView", frame: .zero)
        self.containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.containerView.clipsToBounds = true
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        
        self.topLayoutGuide = .init(owned: containerView)
        self.bottomLayoutGuide = .init(owned: containerView)
        self.contentLayoutGuide = .init(owned: containerView)

        self.navigationLayoutConstraint = topLayoutGuide.heightAnchor.constraint(equalToConstant: 0)
        self.navigationLayoutConstraint.priority = .required - 100

        self.offsetLayoutConstraint = contentLayoutGuide.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor)
        self.offsetLayoutConstraint.priority = .required - 200
        
        NSLayoutConstraint.activate(
            [
                self.topLayoutGuide.topAnchor.constraint(equalTo: containerView.topAnchor),
                self.topLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.topLayoutGuide.rightAnchor.constraint(equalTo: containerView.rightAnchor),

                self.bottomLayoutGuide.topAnchor.constraint(greaterThanOrEqualTo: topLayoutGuide.bottomAnchor),
                self.bottomLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.bottomLayoutGuide.rightAnchor.constraint(equalTo: containerView.rightAnchor),
                self.bottomLayoutGuide.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

                self.contentLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.contentLayoutGuide.rightAnchor.constraint(equalTo: containerView.rightAnchor),
                self.contentLayoutGuide.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor),

                self.offsetLayoutConstraint,
                self.navigationLayoutConstraint,
            ]
        )
    }
    
    private var activedItem: Item? {
        willSet {
            activedItem?.removeObservers()
            newValue?.addObservers()
        }
    }
    
    private var cachedLayerIndex: Int?
    private var cachedContainerHeight: CGFloat?
    private var cachedMaskView: UIView?

    private var topLayoutGuide: XCParallaxableInsetLayoutGuide
    private var bottomLayoutGuide: XCParallaxableInsetLayoutGuide
    private var contentLayoutGuide: XCParallaxableInsetLayoutGuide
    
    private let navigationLayoutConstraint: NSLayoutConstraint
    private let offsetLayoutConstraint: NSLayoutConstraint
    
    private unowned(unsafe) let parallaxable: XCParallaxableController
}


// MARK: -


@dynamicMemberLookup
fileprivate struct XCParallaxableInsetLayoutGuide {
    
    var contentInset: UIEdgeInsets = .zero {
        willSet {
            insetConstraint.map {
                $0[0].constant = newValue.top
                $0[1].constant = newValue.left
                $0[2].constant = newValue.right
                $0[3].constant = newValue.bottom
            }
        }
    }
    
    mutating func constraints(insetTo view: UIView) -> [NSLayoutConstraint] {
        insetConstraint = [
            view.topAnchor.constraint(equalTo: self.topAnchor, constant: contentInset.top),
            view.leftAnchor.constraint(equalTo: self.leftAnchor, constant: contentInset.left),
            self.rightAnchor.constraint(equalTo: view.rightAnchor, constant: contentInset.right),
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: contentInset.bottom)
        ]
        return insetConstraint ?? []
    }
    
    /// Forward getter to the layout guidle.
    subscript<Value>(dynamicMember keyPath: KeyPath<UILayoutGuide, Value>) -> Value {
        get { layoutGuide[keyPath: keyPath] }
    }
    
    init(owned: UIView) {
        owned.addLayoutGuide(layoutGuide)
    }

    private var layoutGuide: UILayoutGuide = .init()
    private var insetConstraint: [NSLayoutConstraint]?
}

fileprivate struct XCParallaxableChangeEvent: OptionSet {
    let rawValue: Int
    static let selectedIndex = Self(rawValue: 0x01)
    static let contentSize = Self(rawValue: 0x02)
    static let contentOffset = Self(rawValue: 0x04)
}


// MARK: -


private extension UIView {
    
    @inline(__always) static func dynamicInit<T>(name: String, frame: CGRect) -> T where T: UIView {
        // Lazy load/register class for name
        func getRuntimeClass() -> T.Type? {
            // If the class already registered, use it directly.
            if let clazz = NSClassFromString(name) as? T.Type {
                return clazz
            }
            // Register a new class.
            if let clazz = objc_allocateClassPair(T.self, name, 0) {
                objc_registerClassPair(clazz)
                return clazz as? T.Type
            }
            return nil
        }
        let clazz = getRuntimeClass() ?? T.self
        return clazz.init(frame: frame)
    }
}

private extension UITableView {
    
    /// Global hotfix used counting, disable hotfix when the count is zero, enable hotfix when the count is nonzero.
    static var _paraxable_hotfixUsedCount: Int = 0 {
        willSet {
            // When enabled or disable not any changes, ignore.
            guard (newValue != 0) != (_paraxable_hotfixUsedCount != 0) else {
                return
            }
            // Quickly swap two implementations.
            if let org = class_getInstanceMethod(Self.self, NSSelectorFromString("_contentInset")),
               let new = class_getInstanceMethod(Self.self, NSSelectorFromString("_paraxable_contentInset")) {
                method_exchangeImplementations(org, new)
            }
        }
    }

    /// We need to changes table view header panned without `setContentInset`, resolved by change `_contentInset`,
    /// But this is a undocumented API, it work in iOS 10 - iOS 15(or more).
    @objc func _paraxable_contentInset() -> UIEdgeInsets {
        var newValue = _paraxable_contentInset()
        if let offset = objc_getAssociatedObject(self, &Self._paraxable_hotfixUsedCount) as? CGFloat {
            newValue.top -= offset
        }
        return newValue
    }
}
