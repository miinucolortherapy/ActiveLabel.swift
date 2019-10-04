//
//  ActiveLabel.swift
//  ActiveLabel
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import Foundation
import UIKit

public protocol ActiveLabelDelegate: class {
    func didSelect(_ text: String, type: ActiveType)
    func didLongPressWithURL(_ url: URL, touchPoint: CGPoint)
}

public typealias ConfigureLinkAttribute = (ActiveType, [NSAttributedString.Key : Any], Bool) -> ([NSAttributedString.Key : Any])
typealias ElementTuple = (range: NSRange, element: ActiveElement, type: ActiveType)

@IBDesignable open class ActiveLabel: UILabel {
    
    // MARK: - public properties
    open weak var delegate: ActiveLabelDelegate?

    open var enabledTypes: [ActiveType] = [.mention, .hashtag, .url]

    open var urlMaximumLength: Int?
    
    open var configureLinkAttribute: ConfigureLinkAttribute?
    
    open var isCopyLinksEnable = false

    @IBInspectable open var mentionColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var mentionSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var hashtagColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var hashtagSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var URLColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var URLSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    open var underlineStyle: [ActiveType: Int] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    open var selectedUnderlineStyle: [ActiveType: Int] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    open var customColor: [ActiveType : UIColor] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    open var customSelectedColor: [ActiveType : UIColor] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var lineSpacing: CGFloat = 0 {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var minimumLineHeight: CGFloat = 0 {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var highlightFontName: String? = nil {
        didSet { updateTextStorage(parseText: false) }
    }
    public var highlightFontSize: CGFloat? = nil {
        didSet { updateTextStorage(parseText: false) }
    }
    
    // MARK: - Computed Properties
    private var hightlightFont: UIFont? {
        guard let highlightFontName = highlightFontName, let highlightFontSize = highlightFontSize else { return nil }
        return UIFont(name: highlightFontName, size: highlightFontSize)
    }
    
    private let menuController = UIMenuController.shared
    private let highlightColor = UIColor(red: 229.0 / 255.0, green: 229.0 / 255.0, blue: 254.0 / 255.0, alpha: 0.7)
    private var lastCopyMenuRect: CGRect = .zero
    private var copyLink: String?

    // MARK: - public methods
    open func handleMentionTap(_ handler: @escaping (String) -> ()) {
        self.hideCopyMenu()
        mentionTapHandler = handler
    }

    open func handleHashtagTap(_ handler: @escaping (String) -> ()) {
        self.hideCopyMenu()
        hashtagTapHandler = handler
    }
    
    open func handleURLTap(_ handler: @escaping (URL) -> ()) {
        self.hideCopyMenu()
        urlTapHandler = handler
    }

    open func handleCustomTap(for type: ActiveType, handler: @escaping (String) -> ()) {
        self.hideCopyMenu()
        customTapHandlers[type] = handler
    }
	
    open func removeHandle(for type: ActiveType) {
        switch type {
        case .hashtag:
            hashtagTapHandler = nil
        case .mention:
            mentionTapHandler = nil
        case .url:
            urlTapHandler = nil
        case .custom, .preview:
            customTapHandlers[type] = nil
        }
    }

    open func filterMention(_ predicate: @escaping (String) -> Bool) {
        mentionFilterPredicate = predicate
        updateTextStorage()
    }

    open func filterHashtag(_ predicate: @escaping (String) -> Bool) {
        hashtagFilterPredicate = predicate
        updateTextStorage()
    }

    // MARK: - override UILabel properties
    override open var text: String? {
        didSet { updateTextStorage() }
    }

    override open var attributedText: NSAttributedString? {
        didSet { updateTextStorage() }
    }
    
    override open var font: UIFont! {
        didSet { updateTextStorage(parseText: false) }
    }
    
    override open var textColor: UIColor! {
        didSet { updateTextStorage(parseText: false) }
    }
    
    override open var textAlignment: NSTextAlignment {
        didSet { updateTextStorage(parseText: false)}
    }

    open override var numberOfLines: Int {
        didSet { textContainer.maximumNumberOfLines = numberOfLines }
    }

    open override var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
    }

    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        self.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func longPress(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: sender.view)
        guard let element = self.element(at: location) else {
            return
        }
        var link: String?
        var url: URL?
        switch element.element {
        case .mention(let userHandle):
            link = "@" + userHandle
            url = URL(string: link!)
        case .hashtag(let hashtag):
            link = "#" + hashtag
            url = URL(string: link!)
        case .url(let originalURL, let trimmed):
            guard let encoded = originalURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
                return
            }
            link = trimmed
            url = URL(string: encoded)
        case .custom(_):
            break
        case .preview(let original, let preview):
            guard let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
                return
            }
            link = preview
            url = URL(string: encoded)
        }
        if let linkUrl = url, let linkString = link {
            self.process(link: linkString, url: linkUrl, touchPoint: location)
        }
    }

    private func process(link: String, url: URL, touchPoint: CGPoint) {
        self.delegate?.didLongPressWithURL(url, touchPoint: touchPoint)
        guard self.isCopyLinksEnable,
            let rect = self.selectedLinkRectangle(link: link, touchPoint: touchPoint),
            self.lastCopyMenuRect != rect else {
            return
        }
        self.lastCopyMenuRect = rect
        self.showCopyMenu(rect: rect)
        self.copyLink = url.description.removingPercentEncoding
    }
    
    private func selectedLinkRectangle(link: String, touchPoint: CGPoint) -> CGRect? {
        guard let text = self.text else {
            return nil
        }
        let linkRanges = self.linkRanges(text: text, link: link)
        for linkRange in linkRanges {
            let characterRange = NSRange(linkRange, in: text)
            let boundRect = self.boundingRectangle(forCharacterRange: characterRange)
            let correctBoundRect = CGRect(x: boundRect.minX, y: boundRect.minY + self.heightCorrection, width: boundRect.width, height: boundRect.height)
            if correctBoundRect.contains(touchPoint) {
                self.highlightLink(range: characterRange)
                return correctBoundRect
            }
        }
        return nil
    }
    
    private func linkRanges(text: String, link: String) -> [Range<String.Index>] {
        var linkRanges = text.ranges(of: link)
        guard let range = link.range(of: "://") else {
            return linkRanges
        }
        let linkRange = range.upperBound..<link.endIndex
        let clippedLink = String(link[linkRange])
        let clippedLinkRanges = text.ranges(of: clippedLink)
        for clippedLinkRange in clippedLinkRanges {
            linkRanges.append(clippedLinkRange)
        }
        return linkRanges
    }
    
    private func boundingRectangle(forCharacterRange range: NSRange) -> CGRect {
        var glyphRange = NSRange(location: 0, length: self.textStorage.length)
        self.layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return boundingRect
    }
    
    private func showCopyMenu(rect: CGRect) {
        guard self.becomeFirstResponder() else {
            self.copyLink = nil
            return
        }
        self.menuController.arrowDirection = .default
        self.menuController.setTargetRect(rect, in: self)
        self.menuController.setMenuVisible(true, animated: true)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.resetHighlight),
            name: UIMenuController.didHideMenuNotification,
            object: nil
        )
    }
    
    private func hideCopyMenu() {
        self.lastCopyMenuRect = .zero
        self.copyLink = nil
        self.menuController.setMenuVisible(false, animated: true)
    }
    
    private func highlightLink(range: NSRange) {
        self.textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: self.textStorage.length))
        self.textStorage.addAttribute(.backgroundColor, value: self.highlightColor, range: range)
        self.setNeedsDisplay()
    }
    
    @objc private func resetHighlight() {
        self.textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: self.textStorage.length))
        self.setNeedsDisplay()
        NotificationCenter.default.removeObserver(self, name: UIMenuController.didHideMenuNotification, object: nil)
    }

    // MARK: - init functions
    override public init(frame: CGRect) {
        super.init(frame: frame)
        _customizing = false
        setupLabel()
        self.setupLongPressGesture()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _customizing = false
        setupLabel()
        self.setupLongPressGesture()
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        updateTextStorage()
        self.setupLongPressGesture()
    }

    open override func drawText(in rect: CGRect) {
        let range = NSRange(location: 0, length: textStorage.length)

        textContainer.size = rect.size
        let newOrigin = textOrigin(inRect: rect)

        layoutManager.drawBackground(forGlyphRange: range, at: newOrigin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: newOrigin)
    }


    // MARK: - customzation
    @discardableResult
    open func customize(_ block: (_ label: ActiveLabel) -> ()) -> ActiveLabel {
        _customizing = true
        block(self)
        _customizing = false
        updateTextStorage()
        return self
    }

    // MARK: - Auto layout

    open override var intrinsicContentSize: CGSize {
        return super.intrinsicContentSize
    }

    // MARK: - touch events
    func onTouch(_ touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        var avoidSuperCall = false
        switch touch.phase {
        case .began, .moved:
            if let element = element(at: location) {
                if element.range.location != selectedElement?.range.location || element.range.length != selectedElement?.range.length {
                    updateAttributesWhenSelected(false)
                    selectedElement = element
                    updateAttributesWhenSelected(true)
                }
                avoidSuperCall = true
            } else {
                updateAttributesWhenSelected(false)
                selectedElement = nil
            }
            self.hideCopyMenu()
        case .ended:
            guard let selectedElement = selectedElement else { return avoidSuperCall }

            switch selectedElement.element {
            case .mention(let userHandle): didTapMention(userHandle)
            case .hashtag(let hashtag): didTapHashtag(hashtag)
            case .url(let originalURL, _): didTapStringURL(originalURL)
            case .custom(let element): didTap(element, for: selectedElement.type)
            case .preview(let original, _): didTap(original, for: selectedElement.type)
            }
            
            let when = DispatchTime.now() + Double(Int64(0.25 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.updateAttributesWhenSelected(false)
                self.selectedElement = nil
            }
            avoidSuperCall = true
        case .cancelled:
            updateAttributesWhenSelected(false)
            selectedElement = nil
        case .stationary:
            break
        }

        return avoidSuperCall
    }

    // MARK: - private properties
    fileprivate var _customizing: Bool = true
    fileprivate var defaultCustomColor: UIColor = .black
    private var defaultUnderlineStyle: NSUnderlineStyle = []
    
    internal var mentionTapHandler: ((String) -> ())?
    internal var hashtagTapHandler: ((String) -> ())?
    internal var urlTapHandler: ((URL) -> ())?
    internal var customTapHandlers: [ActiveType : ((String) -> ())] = [:]
    
    fileprivate var mentionFilterPredicate: ((String) -> Bool)?
    fileprivate var hashtagFilterPredicate: ((String) -> Bool)?

    fileprivate var selectedElement: ElementTuple?
    fileprivate var heightCorrection: CGFloat = 0
    internal lazy var textStorage = NSTextStorage()
    fileprivate lazy var layoutManager = NSLayoutManager()
    fileprivate lazy var textContainer = NSTextContainer()
    lazy var activeElements = [ActiveType: [ElementTuple]]()

    // MARK: - helper functions
    
    fileprivate func setupLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        isUserInteractionEnabled = true
    }

    fileprivate func updateTextStorage(parseText: Bool = true) {
        if _customizing { return }
        // clean up previous active elements
        guard let attributedText = attributedText, attributedText.length > 0 else {
            clearActiveElements()
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }

        let mutAttrString = addLineBreak(attributedText)

        if parseText {
            clearActiveElements()
            let newString = parseTextAndExtractActiveElements(mutAttrString)
            mutAttrString.mutableString.setString(newString)
        }

        addLinkAttribute(mutAttrString)
        textStorage.setAttributedString(mutAttrString)
        _customizing = true
        text = mutAttrString.string
        _customizing = false
        setNeedsDisplay()
    }

    fileprivate func clearActiveElements() {
        selectedElement = nil
        for (type, _) in activeElements {
            activeElements[type]?.removeAll()
        }
    }

    fileprivate func textOrigin(inRect rect: CGRect) -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        heightCorrection = (rect.height - usedRect.height)/2
        let glyphOriginY = heightCorrection > 0 ? rect.origin.y + heightCorrection : rect.origin.y
        return CGPoint(x: rect.origin.x, y: glyphOriginY)
    }

    /// add link attribute
    fileprivate func addLinkAttribute(_ mutAttrString: NSMutableAttributedString) {
        var range = NSRange(location: 0, length: 0)
        var attributes = mutAttrString.attributes(at: 0, effectiveRange: &range)
        
        attributes[NSAttributedString.Key.font] = font!
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        mutAttrString.addAttributes(attributes, range: range)

        attributes[NSAttributedString.Key.foregroundColor] = mentionColor

        for (type, elements) in activeElements {

            switch type {
            case .mention: attributes[NSAttributedString.Key.foregroundColor] = mentionColor
            case .hashtag: attributes[NSAttributedString.Key.foregroundColor] = hashtagColor
            case .url:
                attributes[NSAttributedString.Key.foregroundColor] = URLColor
            case .custom, .preview:
                attributes[NSAttributedString.Key.foregroundColor] = customColor[type] ?? defaultCustomColor
            }
            
            attributes[.underlineStyle] = underlineStyle[type] ?? defaultUnderlineStyle
            
            if let highlightFont = hightlightFont {
                attributes[NSAttributedString.Key.font] = highlightFont
            }
			
            if let configureLinkAttribute = configureLinkAttribute {
                attributes = configureLinkAttribute(type, attributes, false)
            }

            for element in elements {
                mutAttrString.setAttributes(attributes, range: element.range)
            }
        }
    }

    /// use regex check all link ranges
    fileprivate func parseTextAndExtractActiveElements(_ attrString: NSAttributedString) -> String {
        var textString = attrString.string
        var textLength = textString.utf16.count
        var textRange = NSRange(location: 0, length: textLength)
        
        var previewElements: [ElementTuple] = []
        
        for type in enabledTypes {
            guard case let ActiveType.preview(_, preview) = type else {
                continue
            }
            let tuple = ActiveBuilder.createPreviewElements(
                type: type,
                from: textString,
                preview: preview,
                range: textRange,
                filterPredicate: nil)
            previewElements = tuple.0
            let finalText = tuple.1
            textString = finalText
            textLength = textString.utf16.count
            textRange = NSRange(location: 0, length: textLength)
            self.activeElements[type] = previewElements
        }

        if enabledTypes.contains(.url) {
            let tuple = ActiveBuilder.createURLElements(from: textString, range: textRange, maximumLength: urlMaximumLength)
            let urlElements = tuple.0
            let finalText = tuple.1
            textString = finalText
            textLength = textString.utf16.count
            textRange = NSRange(location: 0, length: textLength)
            activeElements[.url] = urlElements
            
            // Adjust preview type ranges after trimming urls
            var newPreviewElements: [ElementTuple] = []
            for element in previewElements {
                let beforeUrls = urlElements.filter({ $0.range.location < element.range.location })
                let trims = beforeUrls.map({ (tuple: ElementTuple) -> Int in
                    if case let ActiveElement.url(original, trimmed) = tuple.element {
                        return original.utf16.count - trimmed.utf16.count
                    }
                    return 0
                })
                let offset = trims.reduce(0, +)
                let newRange = NSRange(location: element.range.location - offset, length: element.range.length)
                newPreviewElements.append((newRange, element.element, element.type))
                self.activeElements[element.type] = newPreviewElements
            }
        }

        for type in enabledTypes where type != .url {
            if case ActiveType.preview(_, _) = type {
                continue
            }
            var filter: ((String) -> Bool)? = nil
            if type == .mention {
                filter = mentionFilterPredicate
            } else if type == .hashtag {
                filter = hashtagFilterPredicate
            }
            let hashtagElements = ActiveBuilder.createElements(type: type, from: textString, range: textRange, filterPredicate: filter)
            activeElements[type] = hashtagElements
        }

        return textString
    }


    /// add line break mode
    fileprivate func addLineBreak(_ attrString: NSAttributedString) -> NSMutableAttributedString {
        let mutAttrString = NSMutableAttributedString(attributedString: attrString)

        var range = NSRange(location: 0, length: 0)
        var attributes = mutAttrString.attributes(at: 0, effectiveRange: &range)
        
        let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.minimumLineHeight = minimumLineHeight > 0 ? minimumLineHeight: self.font.pointSize * 1.14
        attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        mutAttrString.setAttributes(attributes, range: range)

        return mutAttrString
    }

    fileprivate func updateAttributesWhenSelected(_ isSelected: Bool) {
        guard let selectedElement = selectedElement else {
            return
        }
        
        var attributes = textStorage.attributes(at: 0, effectiveRange: nil)
        let type = selectedElement.type

        if isSelected {
            let selectedColor: UIColor
            switch type {
            case .mention: selectedColor = mentionSelectedColor ?? mentionColor
            case .hashtag: selectedColor = hashtagSelectedColor ?? hashtagColor
            case .url: selectedColor = URLSelectedColor ?? URLColor
            case .custom, .preview:
                let possibleSelectedColor = customSelectedColor[selectedElement.type] ?? customColor[selectedElement.type]
                selectedColor = possibleSelectedColor ?? defaultCustomColor
            }
            attributes[NSAttributedString.Key.foregroundColor] = selectedColor
            let possibleUnderlineStyle = selectedUnderlineStyle[selectedElement.type] ?? underlineStyle[selectedElement.type]
            attributes[.underlineStyle] = possibleUnderlineStyle ?? defaultUnderlineStyle
        } else {
            let unselectedColor: UIColor
            switch type {
            case .mention: unselectedColor = mentionColor
            case .hashtag: unselectedColor = hashtagColor
            case .url: unselectedColor = URLColor
            case .custom, .preview: unselectedColor = customColor[selectedElement.type] ?? defaultCustomColor
            }
            attributes[NSAttributedString.Key.foregroundColor] = unselectedColor
            attributes[.underlineStyle] = underlineStyle[selectedElement.type] ?? defaultUnderlineStyle
        }
        
        if let highlightFont = hightlightFont {
            attributes[NSAttributedString.Key.font] = highlightFont
        }
        
        if let configureLinkAttribute = configureLinkAttribute {
            attributes = configureLinkAttribute(type, attributes, isSelected)
        }

        textStorage.addAttributes(attributes, range: selectedElement.range)

        setNeedsDisplay()
    }

    fileprivate func element(at location: CGPoint) -> ElementTuple? {
        guard textStorage.length > 0 else {
            return nil
        }

        var correctLocation = location
        correctLocation.y -= heightCorrection
        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: textStorage.length), in: textContainer)
        guard boundingRect.contains(correctLocation) else {
            return nil
        }

        let index = layoutManager.glyphIndex(for: correctLocation, in: textContainer)
        
        for element in activeElements.map({ $0.1 }).joined() {
            if index >= element.range.location && index <= element.range.location + element.range.length {
                return element
            }
        }

        return nil
    }


    //MARK: - Handle UI Responder touches
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesBegan(touches, with: event)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesMoved(touches, with: event)
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        _ = onTouch(touch)
        super.touchesCancelled(touches, with: event)
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesEnded(touches, with: event)
    }

    //MARK: - ActiveLabel handler
    fileprivate func didTapMention(_ username: String) {
        guard let mentionHandler = self.mentionTapHandler else {
            delegate?.didSelect(username, type: .mention)
            return
        }
        mentionHandler(username)
    }

    fileprivate func didTapHashtag(_ hashtag: String) {
        guard let hashtagHandler = self.hashtagTapHandler else {
            delegate?.didSelect(hashtag, type: .hashtag)
            return
        }
        hashtagHandler(hashtag)
    }

    fileprivate func didTapStringURL(_ stringURL: String) {
        var link = stringURL
        if !link.contains("://") {
            link = "http://" + link
        }
        guard let urlHandler = self.urlTapHandler,
            let encoded = link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
            let url = URL(string: encoded) else {
            delegate?.didSelect(stringURL, type: .url)
            return
        }
        urlHandler(url)
    }

    fileprivate func didTap(_ element: String, for type: ActiveType) {
        guard let elementHandler = customTapHandlers[type] else {
            delegate?.didSelect(element, type: type)
            return
        }
        elementHandler(element)
    }
    
    override open var canBecomeFirstResponder: Bool {
        return self.isCopyLinksEnable
    }
    
    override open func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.copyLink
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(UIResponderStandardEditActions.copy(_:)):
            return true
        default:
            return false
        }
    }
}

extension ActiveLabel: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
