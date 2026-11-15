//
//  CameraMetrics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Sizes of the stock Photo camera in points, measured on a 402 x 874 screen.
enum CameraMetrics {
    enum TopBar {
        static let buttonSize: CGFloat = 41
        static let pitch: CGFloat = 44
        /// The square an item takes a touch in, around the drawn one: the 44 points a finger needs, which the pitch
        /// leaves room for. Our own, not measured.
        static let touchSize: CGFloat = 44
        /// Distance from the top safe area inset to the top of the buttons.
        static let topBelowSafeArea: CGFloat = 5.333
        /// Scale of an item of a scrolling row that has gone out of sight past an edge of the strip. It fades out
        /// as it shrinks to it.
        static let edgeScale: CGFloat = 0.5
    }

    /// The point sizes of the glyphs, the stock ones and the system symbols drawn where the stock camera has none.
    enum Symbol {
        /// Regular weight in the top bar.
        static let topBarPointSize: CGFloat = 18.5
        /// Regular weight in the rows of a sub-panel and light weight in the tiles.
        static let regularPointSize: CGFloat = 22
        /// Regular weight in the glass buttons beside the shutter and in the corners.
        static let buttonPointSize: CGFloat = 17
    }

    /// The column a larger screen lays the camera out in.
    enum Column {
        /// The width of the widest phone screen: a screen up to this wide lays the camera out across its whole
        /// width, and the controls under the viewfinder grow no wider on a larger one.
        static let phoneWidth: CGFloat = 440
    }

    enum Viewfinder {
        /// Height of the black area with the shutter under the 4:3 viewfinder.
        static let controlsHeight: CGFloat = 210
        /// How far the 16:9 viewfinder starts above the 4:3 one.
        static let sixteenByNineRise: CGFloat = 66.667
        /// How far the square viewfinder starts below the 4:3 one.
        static let squareDrop: CGFloat = 51
        /// The most black the stock arrangement leaves between the top bar and the 4:3 viewfinder, on the tallest
        /// phone. A taller window shares the rest of its free height equally above and below the viewfinder.
        static let largestGapAbove: CGFloat = 51
    }

    enum LensRow {
        static let size = CGSize(width: 274, height: 40)
        static let buttonDiameter: CGFloat = 38
        static let pitch: CGFloat = 39
        /// Distance from the row centre down to the bottom edge of the viewfinder.
        static let centerAboveViewfinderBottom: CGFloat = 36
        static let touchSlop: CGFloat = 6
        static let activeShadowOpacity = 0.35
        static let activeShadowRadius: CGFloat = 2
        static let shadowOpacity = 0.9
        static let shadowRadius: CGFloat = 1.333
    }

    enum Shutter {
        static let ringDiameter: CGFloat = 80
        static let discDiameter: CGFloat = 68
        static let centerAboveBottom: CGFloat = 154
        /// The two thin rims of the ring, the outer one and the one inside it.
        static let rimWidth: CGFloat = 2.0 / 3.0
        /// How bright the inner rim is lit, as a share of the outer one.
        static let innerRimShare = 0.47
        /// The width of the spinner in the band between the disc and the rim while the camera processes the photos it
        /// took. The stock spinner's size was not measured.
        static let spinnerWidth: CGFloat = 3
    }

    enum SideButton {
        static let diameter: CGFloat = 48
        static let sideInset: CGFloat = 34
        static let upperCenterAboveBottom: CGFloat = 154
        static let lowerCenterAboveBottom: CGFloat = 58
    }

    enum ModePicker {
        /// Space between the capsule and the round buttons beside it.
        static let sideGap: CGFloat = 9
    }

    enum ZoomDial {
        static let radius: CGFloat = 222
        /// Part of the disc that shows above the bottom edge of the viewfinder.
        static let visibleHeight: CGFloat = 127.667
        static let tickOuterInset: CGFloat = 4.333
        static let tickInnerInset: CGFloat = 21
        static let labelInset: CGFloat = 36.333
        static let focalLengthInset: CGFloat = 52.333
        static let needleSize = CGSize(width: 4, height: 10)
        static let needleInset: CGFloat = 4.333
        static let markDiameter: CGFloat = 3
        /// How far the closed dial sits below its open position, and its scale there.
        static let closedOffset: CGFloat = 55.333
        static let closedScale: CGFloat = 0.75
        /// Distance from a dial label within which a tap on the open dial zooms to that label.
        static let labelTapRadius: CGFloat = 30
    }

    /// The control panel card with the setting tiles, measured on the stock camera of iOS 27.
    enum ControlPanel {
        static let sideInset: CGFloat = 8
        /// Distance from the bottom of the card, and of the sub-panel card, to the bottom of the screen.
        static let bottomInset: CGFloat = 8.333
        static let cornerRadius: CGFloat = 54
        static let grabberSize = CGSize(width: 38, height: 4)
        static let grabberTop: CGFloat = 10
        static let grabberTouchHeight: CGFloat = 30
        static let columns = 3
        static let tileSize = CGSize(width: 120.667, height: 94)
        static let columnPitch: CGFloat = 115.333
        static let rowPitch: CGFloat = 124
        static let tileCircleDiameter: CGFloat = 68
        /// Distance from the top of the card to the centre of the first row of tiles.
        static let firstRowCenter: CGFloat = 84
        /// Distance from the centre of the last row of tiles to the bottom of the card.
        static let lastRowCenterAboveBottom: CGFloat = 108
        /// Distance from the centre of a tile circle down to the middle of the capitals of its label.
        static let labelBelowCircleCenter: CGFloat = 51.333
        static let labelHeight: CGFloat = 16
        /// The least space between two tile labels side by side, and between a label and the edge of the card.
        static let labelSpacing: CGFloat = 4
        /// The smallest share of its size a tile label is set at where it is too long for its width.
        static let labelMinimumScale: CGFloat = 0.7
        /// The card the panel grows from and shrinks back into: a glass blob around the shutter.
        static let seedSize = CGSize(width: 220, height: 120)
        /// How far the grabber has to be dragged down, or flung, to close the panel.
        static let dismissDistance: CGFloat = 60
        static let dismissPredictedDistance: CGFloat = 140
        /// How far a finger moves on the grabber before the card follows it.
        static let grabberMinimumDistance: CGFloat = 4
        /// The most the card gives way to an upward pull, and how soon it nears that.
        static let dragResistanceLimit: CGFloat = 24
        static let dragResistanceStiffness: CGFloat = 0.5
    }

    /// The sub-panel card of one setting, measured on the stock camera of iOS 27. Positions are from its top-left
    /// corner.
    enum SubPanel {
        /// Baseline of the line under the options of the Save sub-panel that names where the photos go.
        static let destinationBaseline: CGFloat = 164.667
        /// Distance between the centres of options that are words, wide enough for the longest translation.
        static let wordOptionPitch: CGFloat = 150
        static let height: CGFloat = 183.667
        /// How far the lens row, the dial and the shutter move up while a sub-panel is open.
        static let controlsLift: CGFloat = 102
        static let backButtonDiameter: CGFloat = 36
        /// The circle the back button takes a touch in, around the drawn one: the 44 points a finger needs. Our own,
        /// not measured.
        static let backButtonTouchDiameter: CGFloat = 44
        static let backButtonCenter = CGPoint(x: 42.667, y: 42.333)
        /// Middle of the title capitals.
        static let titleCenter: CGFloat = 28
        static let titleHeight: CGFloat = 20
        /// Middle of the value capitals.
        static let valueCenter: CGFloat = 74.167
        static let valueHeight: CGFloat = 40
        /// The least space between the back button and the title or the value.
        static let textSpacing: CGFloat = 4
        /// The smallest share of its size the title or the value is set at where it is too long for its line.
        static let textMinimumScale: CGFloat = 0.8
        /// Centre line of the option glyphs and of the exposure ruler.
        static let optionCenterY: CGFloat = 114.667
        static let optionHitHeight: CGFloat = 44
        /// Distance between the centres of neighbouring glyph options in a row of two or three.
        static let optionPitch: CGFloat = 75
        /// Distance between the centres of the four options of the Timer sub-panel.
        static let timerOptionPitch: CGFloat = 56.2
        /// The ticks of the exposure ruler and the centre mark over them, whose bottom ends meet.
        static let rulerTickWidth: CGFloat = 2
        static let rulerTickHeight: CGFloat = 13
        static let rulerCenterMarkHeight: CGFloat = 26
        /// The opacity of a tick of a third of a stop, and of a tick of a whole stop, where neither fades.
        static let rulerMinorTickOpacity = 0.285
        static let rulerMajorTickOpacity = 0.49
    }

    /// The Format sub-panel, measured on the stock camera of iOS 27: the format row, the quality row in the place of
    /// the stock resolution row, and the approximate size of a photo in the place of the stock footnote. Positions
    /// are from the top-left corner of the card.
    enum FormatPanel {
        /// The leading edge of the row labels, "FORMAT" and "QUALITY".
        static let labelLeading: CGFloat = 56.333
        /// The leading edge of the first column of options, its selection bullet included.
        static let firstColumnLeading: CGFloat = 155.333
        /// Distance between the columns of a row of two options.
        static let twoColumnPitch: CGFloat = 91.5
        /// Distance between the columns of a row of three options, the pitch of the stock glyph rows.
        static let threeColumnPitch = SubPanel.optionPitch
        /// The least space between an option and the column after it, and between the last option and the card's
        /// edge.
        static let minimumGap: CGFloat = 4
        /// The least space between the row labels and the first column.
        static let minimumLabelGap: CGFloat = 8
        /// The selection bullet before an option, and the space between it and the option.
        static let bulletSize: CGFloat = 5
        static let bulletGap: CGFloat = 5
        /// The bottom of the selection bullet sits this far above the baseline of its option.
        static let bulletRise: CGFloat = 2.6
        /// The small row labels sit this far above the baseline of the options next to them.
        static let rowLabelRise: CGFloat = 1.333
        /// The space after an option that still takes its tap.
        static let optionTrailingPadding: CGFloat = 10
        static let formatBaseline: CGFloat = 88
        /// Distance between the baselines of two rows.
        static let rowPitch: CGFloat = 44
        static let qualityBaseline = formatBaseline + rowPitch
        /// The baseline of the line with the approximate size of a photo, under the last row.
        static let photoSizeBaseline = qualityBaseline + 32.667
    }

    /// The focus reticle: the square and the exposure slider with its sun, measured on the stock camera of iOS 27
    /// (402 x 874 pt screen).
    enum FocusReticle {
        static let side: CGFloat = 90.333
        static let lineWidth: CGFloat = 1.167
        static let tickLength: CGFloat = 6
        static let tickWidth: CGFloat = 1
        /// Distance from the edge of the square to the centre line of the slider, measured on the phone.
        static let sliderOffset: CGFloat = 21
        static let railLength: CGFloat = 143
        static let railWidth: CGFloat = 1
        /// Free space between the rail and the rays of the sun, above and below it.
        static let railGap: CGFloat = 3
        /// The view of the sun is this much larger than the reach of its rays, and sits this much lower.
        static let sunFramePadding: CGFloat = 0.333
        /// How far the sun centre travels between the two ends of the rail.
        static let sunTravel: CGFloat = 137.667
        /// The farthest a ray of the sun reaches from its centre, at the top of the range.
        static let sunMaximumExtent: CGFloat = 14.5
        /// Stops the rail spans on each side of zero.
        static let railStops = 4.0
        /// The exposure slider maps a finger travel in points to a virtual position along an exponential scale:
        /// `position = pointsForFirstStop / (base - 1) * (base ^ stops - 1)`.
        static let virtualSliderBase = 1.4
        /// Points of finger travel for the first stop away from zero.
        static let virtualSliderPointsForFirstStop = 120.0
        /// Scale of the whole reticle on the first frame of the appear animation.
        static let appearScale: CGFloat = 1.987
        /// Opacity of the whole reticle once it has dimmed. Stock phone screenshot: line rgb 127 109 34 over a dark
        /// preview 16 12 9, full yellow 255 214 0, so (127 - 16) / (255 - 16) = 0.46 and (109 - 12) / (214 - 12) =
        /// 0.48. The stock camera in the simulator dims to 0.36.
        static let dimmedOpacity = 0.47
        /// Lowest opacity of the square while the camera is still focusing.
        static let pulseOpacity = 0.65
    }

    /// The self-timer countdown. None of it was measured on the stock camera.
    enum Countdown {
        static let shadowRadius: CGFloat = 12
        static let shadowOpacity = 0.4
        /// Scale a new digit grows from.
        static let enteringScale: CGFloat = 1.3
        /// Scale an old digit shrinks to while it fades.
        static let leavingScale: CGFloat = 0.8
    }

    /// The message of a camera that does not run. None of it was measured on the stock camera.
    enum Failure {
        static let padding: CGFloat = 32
        /// Between the message and the button under it.
        static let spacing: CGFloat = 8
        /// The least height of the button, for a finger.
        static let actionMinimumHeight: CGFloat = 44
    }

    /// The notice capsule. None of it was measured on the stock camera.
    enum Notice {
        /// Top of the notice row below the top of the viewfinder, or below the line of the top bar.
        static let top: CGFloat = 12
        /// The height of the capsule of one line.
        static let height: CGFloat = 30
        /// The most lines a notice takes: three at the largest text size in the narrowest window, two at the default
        /// size. A longer one would be cut.
        static let maximumLineCount = 3
        /// How far a notice grows with Dynamic Type at most: as the subheadline grows from its 15 pt at the default
        /// text size to its 21 pt at the largest size short of the accessibility sizes.
        static let largestTextScale: CGFloat = 21.0 / 15.0
        static let horizontalPadding: CGFloat = 14
        /// The least space above and below the text, which the capsule keeps around a notice of more lines.
        static let verticalPadding: CGFloat = 6
        static let backgroundOpacity = 0.6
    }
}
