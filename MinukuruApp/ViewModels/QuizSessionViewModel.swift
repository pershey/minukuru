import Foundation

@MainActor
final class QuizSessionViewModel: ObservableObject {
    @Published private(set) var question: QuizQuestion
    @Published var selectedSegmentIds: Set<String> = []
    @Published var selectedReasonTags: Set<ReasonTag> = []
    @Published var isHintPresented = false

    private unowned let appViewModel: AppViewModel

    init(question: QuizQuestion, appViewModel: AppViewModel) {
        self.question = question
        self.appViewModel = appViewModel
    }

    var canSubmit: Bool {
        !selectedSegmentIds.isEmpty
    }

    var recommendedTags: [ReasonTag] {
        let ordered = question.recommendedReasonTags + ReasonTag.allCases
        var seen = Set<String>()
        return ordered.filter { seen.insert($0.id).inserted }
    }

    func toggleSegment(_ segmentID: String) {
        if selectedSegmentIds.contains(segmentID) {
            selectedSegmentIds.remove(segmentID)
        } else {
            selectedSegmentIds.insert(segmentID)
        }
    }

    func toggleTag(_ tag: ReasonTag) {
        if selectedReasonTags.contains(tag) {
            selectedReasonTags.remove(tag)
        } else {
            selectedReasonTags.insert(tag)
        }
    }

    func submit() {
        let evaluation = evaluate()
        appViewModel.showResult(for: self, evaluation: evaluation)
    }

    private func evaluate() -> QuizEvaluation {
        QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: selectedSegmentIds,
            selectedReasonTags: selectedReasonTags
        )
    }
}
