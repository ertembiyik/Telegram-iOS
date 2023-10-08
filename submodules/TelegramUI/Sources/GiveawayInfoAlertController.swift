import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import AccountContext
import AlertUI
import PresentationDataUtils
import Markdown

private final class GiveawayInfoAlertContentNode: AlertContentNode {
    private let title: String
    private let text: String
    private let warning: String?
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    fileprivate let warningBackgroundNode: ASImageNode
    fileprivate let warningTextNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
        
    public var theme: PresentationTheme
    
    public override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    public init(theme: AlertControllerTheme, ptheme: PresentationTheme, title: String, text: String, warning: String?, actions: [TextAlertAction]) {
        self.theme = ptheme
        self.title = title
        self.text = text
        self.warning = warning
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.warningBackgroundNode = ASImageNode()
        self.warningBackgroundNode.displaysAsynchronously = false
        
        self.warningTextNode = ImmediateTextNode()
        self.warningTextNode.maximumNumberOfLines = 0
        self.warningTextNode.lineSpacing = 0.1
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.warningBackgroundNode)
        self.addSubnode(self.warningTextNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
                
        self.updateTheme(theme)
    }

    public override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor)
        let attributedText = parseMarkdownIntoAttributedString(self.text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
        
        self.textNode.attributedText = attributedText
        
        self.warningTextNode.attributedText = NSAttributedString(string: self.warning ?? "", font: Font.semibold(13.0), textColor: theme.destructiveColor, paragraphAlignment: .center)
        self.warningBackgroundNode.image = generateStretchableFilledCircleImage(radius: 5.0, color: theme.destructiveColor.withAlphaComponent(0.1))
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
                
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    public override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 6.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        if "".isEmpty {
            effectiveActionLayout = .vertical
        }
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        
        var warningHeight: CGFloat = 0.0
        if let _ = self.warning {
            let warningSize = self.warningTextNode.updateLayout(measureSize)
            let warningFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - warningSize.width) / 2.0), y: origin.y + 20.0), size: warningSize)
            transition.updateFrame(node: self.warningTextNode, frame: warningFrame)
            
            transition.updateFrame(node: self.warningBackgroundNode, frame: warningFrame.insetBy(dx: -8.0, dy: -8.0))
            
            warningHeight += warningSize.height + 26.0
        }
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + 8.0 + actionsHeight + warningHeight + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
            case .horizontal:
                if nodeIndex == self.actionNodes.count - 1 {
                    currentActionWidth = resultSize.width - actionOffset
                } else {
                    currentActionWidth = actionWidth
                }
            case .vertical:
                currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

func giveawayInfoAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, title: String, text: String, warning: String?, actions: [TextAlertAction]) -> AlertController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                
    let contentNode = GiveawayInfoAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, title: title, text: text, warning: warning, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }

    return controller
}