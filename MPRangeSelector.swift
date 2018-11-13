//
//  MPRangeSelector.swift
//

import Foundation

protocol MPRangeSelectorDelegate: class {
    
    func onPositionUpdated(_ rangeSelector: MPRangeSelector, newStartRatio: Double)
    
    func onPositionUpdated(_ rangeSelector: MPRangeSelector, newEndRatio: Double)
    
    func onPositionsUpdated(_ rangeSelector: MPRangeSelector, newStartRatio: Double, newEndRatio: Double)
}


class HitTestView: UIView {

    var hitTestInsets = UIEdgeInsetsMake(-10, -10, -10, -10)
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let relativeFrame = self.bounds
        let hitFrame = UIEdgeInsetsInsetRect(relativeFrame, hitTestInsets)
        return hitFrame.contains(point)
    }
}


class HandleView: HitTestView {
    
    var backViewColor: UIColor = UIColor(red: 1.0, green: 41.0/255.0, blue: 88.0/255.0, alpha: 1.0)
    var brandWidth: CGFloat
    var imageWidth: CGFloat
    
    private let backView = UIView()
    private let handleImageView = UIImageView(image: UIImage(named: "video_handle"))
    
    init(brandWidth: CGFloat = 5, imageWidth: CGFloat = 20) {
        self.brandWidth = brandWidth
        self.imageWidth = imageWidth
        super.init(frame: .zero)
        backView.backgroundColor = backViewColor
        self.addSubview(backView)
        self.addSubview(handleImageView)
        setup()
    }
    
   private func setup() {
        backView.snp.makeConstraints { (make) in
            make.width.equalTo(brandWidth)
            make.height.equalTo(self)
            make.center.equalTo(self)
        }
        
        handleImageView.snp.makeConstraints { (make) in
            make.width.height.equalTo(imageWidth)
            make.center.equalTo(self)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class MPRangeSelector: UIView {
    
    enum PanOnView {
        case left
        case right
        case middle
        case none
    }
    
    // subviews
    let startHandleView: HandleView
    let endHandleView: HandleView
    
    var shadowColor: UIColor {
        didSet{
            self.startShadowLayer.backgroundColor =  self.shadowColor.cgColor
            self.endShadowLayer.backgroundColor = self.shadowColor.cgColor
        }
    }
    
    fileprivate var minDurationLength: CGFloat {
        get {
            return CGFloat(minDurationRatio) * (endBound - startBound)
        }
    }
    
    var minDurationRatio: Double = 0.5
    var handleWidth: CGFloat = 40
    
    var handleBrandWidth: CGFloat = 5
    var handleImageWidth: CGFloat = 20
    
    
    weak var delegate: MPRangeSelectorDelegate?
    
    // shadow layers
    private let startShadowLayer = CALayer()
    private let endShadowLayer = CALayer()
    private let panGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    private var panOnView: PanOnView = .none
    
    private var startX: CGFloat = 0
    private var distance: CGFloat = 0
    private var lastTranslationX: CGFloat = 0
    
    private var startBound: CGFloat {
        return -handleWidth / 2.0 + handleBrandWidth / 2.0
    }
    private var endBound: CGFloat {
        return self.width - handleWidth / 2.0 - handleBrandWidth / 2.0
    }
    
    
    init(delegate: MPRangeSelectorDelegate?, minDurationRatio: Double) {
        
        self.delegate = delegate
        self.minDurationRatio = minDurationRatio
        
        self.startHandleView = HandleView(brandWidth: handleBrandWidth, imageWidth: handleImageWidth)
        self.endHandleView = HandleView(brandWidth: handleBrandWidth, imageWidth: handleImageWidth)
        
        self.shadowColor = UIColor.black.withAlphaComponent(0.6)
        super.init(frame: .zero)
        self.clipsToBounds = true
        setupViews()
    }
    
    private func setupViews() {
        
        startShadowLayer.backgroundColor = shadowColor.cgColor
        self.layer.addSublayer(startShadowLayer)
        self.addSubview(startHandleView)
        
        endShadowLayer.backgroundColor = shadowColor.cgColor
        self.layer.addSublayer(endShadowLayer)
        self.addSubview(endHandleView)
        
        panGesture.addTarget(self, action: #selector(onPan(_:)))
        self.addGestureRecognizer(panGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.frame.size
        startShadowLayer.frame = CGRectMake(0, 0, 0, size.height)
        endShadowLayer.frame = CGRectMake(size.width, 0, 0, size.height)
        
        var handleViewFrame = CGRectMake(startBound, 0, handleWidth, self.height)
        self.startHandleView.frame = handleViewFrame
        handleViewFrame.left = endBound
        self.endHandleView.frame = handleViewFrame
        
        self.startHandleView.setNeedsUpdateConstraints()
        self.endHandleView.setNeedsUpdateConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onPan(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began {
            let originalTouchPoint = pan.location(ofTouch: 0, in: self)
            var touchPoint = self.convert(originalTouchPoint, to: startHandleView)
            if startHandleView.point(inside: touchPoint, with: nil) {
                panOnView = .left
            } else{
                touchPoint = self.convert(originalTouchPoint, to: endHandleView)
                if endHandleView.point(inside: touchPoint, with: nil) {
                    panOnView = .right
                }
                else {
                    touchPoint = originalTouchPoint
                    let frame = CGRect(startHandleView.right, 0, endHandleView.left - startHandleView.right, self.height)
                    if frame.contains(touchPoint) {
                        panOnView = .middle
                    } else {
                        panOnView = .none
                    }
                }
            }
        }
        switch panOnView {
        case .left:
            dragHandle(pan, isLeft: true)
        case .right:
            dragHandle(pan, isLeft: false)
        case .middle:
            dragMiddleHandle(pan)
        default:
            break
        }
    }
    
    private func dragMiddleHandle(_ pan: UIPanGestureRecognizer) {
        
        switch (pan.state) {
        case .began:
            lastTranslationX = 0
            startX = startHandleView.left
            distance = endHandleView.left - startHandleView.left
        case .changed:
            let dragRight = pan.translation(in: self).x - lastTranslationX > 0
            mp_print("\(pan.translation(in: self).x)   \(dragRight)")
            lastTranslationX = pan.translation(in: self).x
            if dragRight {
                // first right view
                var newX = startX + distance + pan.translation(in: self).x
                let lowerBound = startHandleView.left + distance
                let upperBound = endBound
                newX = max(lowerBound, min(newX, upperBound))
                endHandleView.left = newX
                updateShadowLayer(offsetX: endHandleView.left + handleWidth / 2, isLeft: false)
                
                // then left view
                startHandleView.left = endHandleView.left - distance
                updateShadowLayer(offsetX: startHandleView.left + handleWidth / 2, isLeft: true)
                
            } else {
                // first left view
                var newX = startX + pan.translation(in: self).x
                let lowerBound = startBound
                let upperBound = endHandleView.left - distance
                
                newX = max(lowerBound, min(newX, upperBound))
                startHandleView.left = newX
                updateShadowLayer(offsetX: startHandleView.left + handleWidth / 2, isLeft: true)
                
                // then right view
                endHandleView.left = startHandleView.left + distance
                updateShadowLayer(offsetX: endHandleView.left + handleWidth / 2, isLeft: false)
            }
            let startRatio = (startHandleView.left - startBound) / (endBound - startBound)
            let endRatio = (endHandleView.left - startBound) / (endBound - startBound)
            delegate?.onPositionsUpdated(self, newStartRatio: Double(startRatio), newEndRatio: Double(endRatio))
            
        default:
            break
        }
    }
    
    private func dragHandle(_ pan: UIPanGestureRecognizer, isLeft: Bool) {
        
        let handleView = isLeft ? startHandleView : endHandleView
        
        switch (pan.state) {
        case .began:
            startX = handleView.left
            
        case .changed:
            let newX = startX + pan.translation(in: self).x
            let lowerBound = isLeft ? startBound :  minDurationLength + startHandleView.left
            let upperBound = isLeft ? endHandleView.left - minDurationLength : endBound
            handleView.left = max(lowerBound, min(newX, upperBound))
            let offsetX = handleView.left + handleWidth / 2
            updateShadowLayer(offsetX: offsetX, isLeft: isLeft)
            if isLeft {
                let startRatio = (startHandleView.left - startBound) / (endBound - startBound)
                delegate?.onPositionUpdated(self, newStartRatio: Double(startRatio))
            } else {
                let endRatio = (endHandleView.left - startBound) / (endBound - startBound)
                delegate?.onPositionUpdated(self, newEndRatio: Double(endRatio))
            }
            
        default:
            break
        }
    }
    
    private func updateShadowLayer(offsetX: CGFloat, isLeft: Bool) {
        // force ui update in current runloop to have smooth experience
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isLeft {
            let shadowFrame = CGRectMake(0, 0, offsetX, self.height)
            startShadowLayer.frame = shadowFrame
        } else {
            let shadowFrame = CGRectMake(offsetX, 0, self.width - offsetX, self.height)
            endShadowLayer.frame = shadowFrame
        }
        CATransaction.commit()
    }
}
