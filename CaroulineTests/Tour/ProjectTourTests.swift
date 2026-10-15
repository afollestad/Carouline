//
//  ProjectTourTests.swift
//  CaroulineTests
//

import Testing
@testable import Carouline

/// The tour's rules, apart from TipKit, which only the app configures.
@MainActor
struct ProjectTourTests {
    /// Whatever finishes a step has moved past the ones before it.
    @Test func finishesEveryEarlierStep() {
        #expect(TourVisit.steps(through: .slideMenu) == [.slideMenu])
        #expect(TourVisit.steps(through: .selectLayer) == [.slideMenu, .selectLayer])
        #expect(TourVisit.steps(through: .share) == TourStep.allCases)
    }

    @Test func offersTheTourStepOnceTheScreenSettles() {
        var visit = TourVisit()
        #expect(!visit.offersSettledTip(.slideMenu, current: .slideMenu))

        visit.isSettled = true
        #expect(visit.offersSettledTip(.slideMenu, current: .slideMenu))
        #expect(visit.offersSettledTip(.share, current: .share))
        #expect(!visit.offersSettledTip(.share, current: .slideMenu))
        #expect(!visit.offersSettledTip(.slideMenu, current: nil))
    }

    /// The layer tip needs a layer on the slide in front to point at, and the move hint waits for
    /// a layer to be selected rather than the screen to settle.
    @Test func pointsAtALayerOnlyWhenThereIsOne() {
        var visit = TourVisit()
        visit.isSettled = true
        #expect(!visit.offersSettledTip(.selectLayer, current: .selectLayer))

        visit.canPointAtLayer = true
        #expect(visit.offersSettledTip(.selectLayer, current: .selectLayer))
        #expect(!visit.offersSettledTip(.moveLayer, current: .moveLayer))
    }

    @Test func showsTheMoveHintOnlyWithRoomAndNothingOpen() {
        #expect(TourVisit.offersMoveTip(current: .moveLayer, isPresenting: false, isCompactHeight: false))
        #expect(!TourVisit.offersMoveTip(current: .moveLayer, isPresenting: true, isCompactHeight: false))
        #expect(!TourVisit.offersMoveTip(current: .moveLayer, isPresenting: false, isCompactHeight: true))
        #expect(!TourVisit.offersMoveTip(current: .share, isPresenting: false, isCompactHeight: false))
    }

    /// Reaching the move hint with nothing selected, as when the layer tip is closed or a visit
    /// starts there, skips it rather than holding back the Share tip.
    @Test func skipsTheMoveHintWithNothingSelected() {
        #expect(TourVisit.stepSkipped(at: .moveLayer, isLayerSelected: false) == .moveLayer)
        #expect(TourVisit.stepSkipped(at: .moveLayer, isLayerSelected: true) == nil)
        #expect(TourVisit.stepSkipped(at: .selectLayer, isLayerSelected: false) == nil)
    }
}
