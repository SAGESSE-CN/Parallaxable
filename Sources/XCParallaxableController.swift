//
//  XCParallaxableController.swift
//  XCParallaxable
//
//  Created by SAGESSE on 2020/12/30.
//

import UIKit


@objc public protocol XCParallaxable {
    
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
@objc open class XCParallaxableController: UIViewController {

    /// The view that displays in the status bar or navigation bar content.
    ///
    /// When assigning a view to this property, the height of the view from:
    /// - Using `heightConstraint` when `constraint.priority` > 900.
    /// - Using `intrinsicContentSize.height` when `contentHuggingPriority` > 900.
    /// - Using `navigationBar.frame.height` when not match cases.
    @objc open var heaerView: UIView? {
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
            // When the view controller not any changes, ignore
            guard newValue != viewControllers else {
                return
            }
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
    
    
    /// The point at which the origin of the parallaxing view is offset from the origin of the parallaxable controller.
    @objc open var contentOffset: CGPoint {
        return cachedContentOffset
    }
    
    /// The size of the parallaxable controller content.
    @objc open var contentSize: CGSize {
        return cachedContentSize
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
        
        // Executing these changes maybe make more new changes,
        // we need to prevent is a called recursively,
        // because recursively is dangerous.
        performWithoutContentChangesIfNeeded {
            // Synchronize into pagging.
            pagging.layoutSubviews()
            pagging.setSelectedIndex(pagging.contentOffset, animated: false)
            
            // Synchronize into parallaxing.
            let item = scrollableItem(at: pagging.contentOffset)
            parallaxing.layoutSubviews()
            parallaxing.move(to: item, from: view)
            parallaxing.setContentOffset(item, animated: false)
        }
    }
    
    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        // Synchronize into parallaxing.
        performWithoutContentChangesIfNeeded {
            parallaxing.safeAreaInsets = view.safeAreaInsets
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

    
    /// Perform something should not trigger the content changes of prevents recursive calls version.
    fileprivate func performWithoutContentChangesIfNeeded(_ actions: () -> Void) {
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
        applyUpdateChangesIfNeeded()
    }
    
    
    /// Gets current vertical scrollable item with conetnt offset.
    fileprivate func scrollableItem(at offset: CGPoint) -> XCParallaxableItem? {
        // Only item that are fully displayed can be vertical scrollable,
        guard let item = pagging.selectedItem, fmod(offset.x, pagging.frame.width) == 0 else {
            return nil
        }
        return item
    }
    
    
    /// Mark set selected index is changed.
    fileprivate func setNeedsUpdateSelected() {
        changes.insert(.selectedIndex)
        applyUpdateChangesIfNeeded()
    }
    
    /// Mark set content size is changed.
    fileprivate func setNeedsUpdateContentSize() {
        changes.insert(.contentSize)
        applyUpdateChangesIfNeeded()
    }
    
    /// Mark set content offset is changed.
    fileprivate func setNeedsUpdateContentOffset() {
        changes.insert(.contentOffset)
        applyUpdateChangesIfNeeded()
    }
    
    /// Apply all changes to this.
    fileprivate func applyUpdateChangesIfNeeded() {
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
        if let _ = changes.remove(.selectedIndex) {
            // When the visabled index is changes, update the status bar.
            setNeedsStatusBarAppearanceUpdate()
            
            // Tells the user the current page is changed.
            delegate?.parallaxableController?(self, didSelectItemAt: selectedIndex)
        }
    }
    
    
    private var changes: XCParallaxableChangeEvent = []
    
    private var isMergeChanges: Bool = false
    private var isLockedConentChanges: Bool = false
    private var isLockedParallaxingView: Bool = true
    
    private var isAutomaticallyLinking: Bool = false
    
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
fileprivate final class XCParallaxableItem {
    
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
        
        // When the view controller appear in the view hierarchy, synchronize
        // The changes that occurred before the view controller was appear.
        parallaxable.performWithoutContentChanges {
            let parallaxing = parallaxable.parallaxing
            updateContentInset(parallaxing.contentInset)
            updateScrollIndicatorInset(parallaxing.contentOffset)
            updateContentOffset(parallaxing.contentOffset)
        }
    }
    
    /// Prepare the view that the controller manages.
    func loadView() {
        // Force the view to load and update the view frame.
        viewController.view.frame = frame
        viewController.view.autoresizingMask = []
        
        // Check that view controller is confirm a protocol then cached it for execution faster
        scrollView = scrollableView()
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

    /// Update the content offset of the scrollable view with new content offset.
    func updateContentOffset(_ newValue: CGPoint) {
        // When the scroll view is not found, ignore.
        guard let scrollView = scrollViewIfLoaded else {
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
    /// Update the content inset of the scrollable view with new content inset.
    func updateContentInset(_ newValue: UIEdgeInsets)  {
        // When the scroll view is not found, ignore.
        guard let scrollView = scrollViewIfLoaded else {
            return
        }
        
        // Fix the safe area insets to content insets.
        var fixedValue = newValue
        if scrollView.contentInsetAdjustmentBehavior != .never {
            fixedValue.top -= parallaxable.parallaxing.safeAreaInsets.top
        }
        
        // When the contet insets is not any changes, ignore.
        guard fixedValue != contentInset else {
            return
        }
        
        var newContentInset = scrollView.contentInset
        var newScrollIndicatorInset = scrollView.scrollIndicatorInsets
        
        newContentInset.top += fixedValue.top - contentInset.top
        newContentInset.left += fixedValue.left - contentInset.left
        newContentInset.right += fixedValue.right - contentInset.right
        newContentInset.bottom += fixedValue.bottom - contentInset.bottom
        
        newScrollIndicatorInset.top += fixedValue.top - contentInset.top
        newScrollIndicatorInset.left += fixedValue.left - contentInset.left
        newScrollIndicatorInset.right += fixedValue.right - contentInset.right
        newScrollIndicatorInset.bottom += fixedValue.bottom - contentInset.bottom
        
        // When the update content insets will cause content offset changes,
        // so we must restore origin content offset after updated.
        performWithoutContentChanges {
            scrollView.contentInset = newContentInset
            scrollView.scrollIndicatorInsets = newScrollIndicatorInset
        }
        
        // Update the cache after the set content inset successfully.
        contentInset = fixedValue
    }
    /// Update the scroll indicator inset of scrollable view with content offset.
    func updateScrollIndicatorInset(_ newValue: CGPoint) {
        // When the scroll view is not found, ignore.
        guard let scrollView = scrollViewIfLoaded else {
            return
        }
        
        // When the content offset not any changes, ignore.
        guard newValue != contentOffset else {
            return
        }
        
        // Fix indicator insets wrong due to content offset.
        scrollView.scrollIndicatorInsets.top -= newValue.y - contentOffset.y
        
        // Update the cache after the set content offset successfully.
        contentOffset = newValue
    }
    
    /// Gets the scrollable view that in the view hierarchy.
    func scrollableView() -> UIScrollView? {
        // When the controller implements the `XCParallaxable`, that get the
        // scrollable view can be faster and securely.
        if let source = viewController as? XCParallaxable {
            return source.scrollableView
        }
        if let source = viewController as? UITableViewController {
            return source.tableView
        }
        if let source = viewController as? UICollectionViewController {
            return source.collectionView
        }
        return nil
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
    
    private var contentInset: UIEdgeInsets = .zero
    private var contentOffset: CGPoint = .zero
    
    private unowned let parallaxable: XCParallaxableController
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
        items.filter { item in newValue.contains { $0 === item } }.forEach {
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
        //
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
    
    private unowned let parallaxable: XCParallaxableController
}


// MARK: -


@dynamicMemberLookup
fileprivate final class XCParallaxableParallaxing<Item, ContainerView> where Item: XCParallaxableItem, ContainerView: UIView {
    
    /// The container of displaying content.
    let containerView: ContainerView
    
    /// The header view of parallaxing view.
    var headerView: UIView? {
        willSet {
            replace(newValue, from: headerView, layoutGuide: topLayoutGuide)
        }
    }
    /// The contnet view of parallaxing view.
    var contentView: UIView? {
        willSet {
            replace(newValue, from: contentView, layoutGuide: contentLayoutGuide)
            newValue.map {
                containerView.sendSubviewToBack($0)
            }
        }
    }
    /// The footer view of parallaxing view.
    var footerView: UIView? {
        willSet {
            replace(newValue, from: footerView, layoutGuide: bottomLayoutGuide)
        }
    }

    /// The all managed items with added to view controller of parallaxable controller.
    var items: [Item] = []
    /// Update the all managed items with added to view controller of parallaxable controller.
    func setItems(_ newValue: [Item], animated: Bool) {
        items = newValue
    }
    
    /// The insets that you use to determine the safe area for parallaxing view.
    var safeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            // When the safeAreaInsets is changes, must synchronize to all contents.
            guard safeAreaInsets != oldValue else {
                return
            }
            navigationLayoutConstraint.constant = safeAreaInsets.top
            performWithoutContentChanges {
                $0.updateContentInset(contentInset)
            }
        }
    }
    
    /// The extra distance that the parallaxing view is inset from the scrollable view edges.
    var contentInset: UIEdgeInsets = .zero {
        willSet {
            // When the contentInset not any changes, ignore.
            guard newValue != contentInset else {
                return
            }
            performWithoutContentChanges {
                $0.updateContentInset(newValue)
            }
        }
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
            offsetLayoutConstraint.constant = -newValue.y
            performWithoutContentChanges {
                $0.updateScrollIndicatorInset(newValue)
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
            return
        }
        contentOffset.y = newValue
        parallaxable.setNeedsUpdateContentOffset()
    }

    /// A Boolean value that indicates whether has begun should render.
    var shouldRenderInHierarchy: Bool {
        return headerView != nil || contentView != nil || footerView != nil
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
    func move(to content: Item?, from superview: UIView) {
        // When the contanier is not ready, ignore.
        guard shouldRenderInHierarchy else {
            // TODO: removeFromSuperview and cache
            return
        }
        // When the scrollable view not found, revert to the superview.
        let newSuperview = content?.scrollViewIfLoaded ?? superview
        guard newSuperview !== containerView.superview else {
            return
        }
        // Remove superview will clean all related constraints.
        containerView.removeFromSuperview()
        newSuperview.addSubview(containerView)
        layoutSubviews()
        
        // Always pinned the container to superview.
        NSLayoutConstraint.activate(
            [
                containerView.topAnchor.constraint(equalTo: superview.topAnchor),
                containerView.leftAnchor.constraint(equalTo: superview.leftAnchor),
                containerView.rightAnchor.constraint(equalTo: superview.rightAnchor),
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
        topLayoutFrame = topLayoutGuide.layoutFrame
        bottomLayoutFrame = bottomLayoutGuide.layoutFrame
        contentLayoutFrame = contentLayoutGuide.layoutFrame
        
        // When the content inset not any changes, ignore.
        let top = topLayoutFrame.height + contentLayoutFrame.height + bottomLayoutFrame.height
        guard top != contentInset.top else {
            return
        }
        contentInset.top = top

        // When the content size not any change, ignore.
        let newConetntHeight = contentLayoutFrame.height
        guard newConetntHeight != contentSize.height else {
            return
        }
        contentSize.height = newConetntHeight
        parallaxable.setNeedsUpdateContentSize()
    }
    
    /// Replace the subview of the layout guide.
    private func replace(_ newValue: UIView?, from oldValue: UIView?, layoutGuide: UILayoutGuide) {
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
        containerView.addConstraints(
            [
                newValue.topAnchor.constraint(equalTo: layoutGuide.topAnchor),
                newValue.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor),
                
                newValue.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                newValue.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            ]
        )
    }
    
    /// Create a custom pagging manager.
    init(_ parallaxable: XCParallaxableController) {
        //
        self.parallaxable = parallaxable
        
        self.topLayoutGuide = .init()
        self.bottomLayoutGuide = .init()
        self.contentLayoutGuide = .init()
        
        self.containerView = ContainerView.dynamicInit(name: "XCParallaxablePresentedView", frame: .zero)
        self.containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.containerView.clipsToBounds = true
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        
        self.containerView.addLayoutGuide(topLayoutGuide)
        self.containerView.addLayoutGuide(contentLayoutGuide)
        self.containerView.addLayoutGuide(bottomLayoutGuide)

        self.navigationLayoutConstraint = topLayoutGuide.heightAnchor.constraint(equalToConstant: 0)
        self.navigationLayoutConstraint.priority = .required - 100

        self.offsetLayoutConstraint = contentLayoutGuide.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor)
        self.offsetLayoutConstraint.priority = .defaultLow - 1
        
        
        NSLayoutConstraint.activate(
            [
                self.topLayoutGuide.topAnchor.constraint(equalTo: containerView.topAnchor),
                self.topLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.topLayoutGuide.widthAnchor.constraint(equalToConstant: 0),

                self.bottomLayoutGuide.topAnchor.constraint(greaterThanOrEqualTo: topLayoutGuide.bottomAnchor),
                self.bottomLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.bottomLayoutGuide.widthAnchor.constraint(equalToConstant: 0),
                self.bottomLayoutGuide.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

                self.contentLayoutGuide.leftAnchor.constraint(equalTo: containerView.leftAnchor),
                self.contentLayoutGuide.rightAnchor.constraint(equalTo: containerView.leftAnchor),
                self.contentLayoutGuide.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor),

                self.offsetLayoutConstraint,
                self.navigationLayoutConstraint,
            ]
        )
    }
    
    private var cachedContainerHeight: CGFloat?

    private var topLayoutFrame: CGRect = .zero
    private var bottomLayoutFrame: CGRect = .zero
    private var contentLayoutFrame: CGRect = .zero
    
    private let topLayoutGuide: UILayoutGuide
    private let bottomLayoutGuide: UILayoutGuide
    private let contentLayoutGuide: UILayoutGuide
    
    private let navigationLayoutConstraint: NSLayoutConstraint
    private let offsetLayoutConstraint: NSLayoutConstraint
    
    private unowned let parallaxable: XCParallaxableController
}


// MARK: -


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
