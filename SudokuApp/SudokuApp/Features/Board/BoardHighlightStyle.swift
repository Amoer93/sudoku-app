/// 「高亮行列宫」用到的常量，集中在一处方便调整和测试。
enum BoardHighlightStyle {
    /// 开关在本地存储里的键名
    static let storageKey = "highlightPeers"
    /// 开关默认值：打开
    static let defaultEnabled = true
    /// 同行、同列、同宫格子叠加的深色透明度
    static let peerOverlay = 0.10
    /// 蒙版底色格叠加得更淡，避免盖掉本层的颜色
    static let tintedPeerOverlay = 0.08
}
