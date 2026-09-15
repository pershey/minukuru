import Foundation

@MainActor
final class QuizSessionViewModel: ObservableObject {
    @Published private(set) var question: QuizQuestion
    @Published var selectedSegmentIds: Set<String> = []
    @Published var selectedReasonTags: Set<ReasonTag> = []
    @Published var selectedChoiceId: String?
    @Published private(set) var phase: QuizSessionPhase = .answer
    @Published private(set) var hasUsedHint = false
    @Published var isHintPresented = false

    let attemptNumber: Int

    private unowned let appViewModel: AppViewModel

    init(
        question: QuizQuestion,
        appViewModel: AppViewModel,
        snapshot: QuizSessionSnapshot? = nil,
        attemptNumber: Int = 1
    ) {
        self.question = question
        self.appViewModel = appViewModel
        self.attemptNumber = max(snapshot?.attemptNumber ?? attemptNumber, 1)
        phase = snapshot?.phase ?? .answer
        selectedSegmentIds = Set(snapshot?.selectedSegmentIDs ?? [])
        selectedReasonTags = Set(snapshot?.selectedReasonTags ?? [])
        selectedChoiceId = snapshot?.selectedChoiceID
        hasUsedHint = snapshot?.hintUsed ?? false

        if question.learningStage == .example, selectedSegmentIds.isEmpty {
            selectedSegmentIds = Set(question.correctSegmentIds)
        }
    }

    var canSubmit: Bool {
        switch phase {
        case .answer:
            if question.learningStage == .example {
                return true
            }
            switch question.responseType {
            case .selectSegments:
                return !selectedSegmentIds.isEmpty
            case .singleChoice:
                return selectedChoiceId != nil
            }
        case .reason:
            return !selectedReasonTags.isEmpty
        }
    }

    var recommendedTags: [ReasonTag] {
        let recommended = question.recommendedReasonTags.prefix(2)
        let distractors = ReasonTag.allCases
            .filter { !question.recommendedReasonTags.contains($0) }
            .sorted { stableOrder(for: $0) < stableOrder(for: $1) }
            .prefix(max(4 - recommended.count, 0))
        let ordered = Array(recommended) + Array(distractors)
        var seen = Set<String>()
        return ordered
            .filter { seen.insert($0.id).inserted }
            .sorted { stableOrder(for: $0) < stableOrder(for: $1) }
    }

    var isGuidedExample: Bool {
        question.learningStage == .example
    }

    var primaryActionTitle: String {
        if isGuidedExample {
            return "お手本の答えを見る"
        }
        if phase == .answer, question.responseType == .selectSegments {
            return "理由を考える"
        }
        return "答えを見る"
    }

    func toggleSegment(_ segmentID: String) {
        guard !isGuidedExample, phase == .answer else { return }
        if selectedSegmentIds.contains(segmentID) {
            selectedSegmentIds.remove(segmentID)
        } else {
            selectedSegmentIds.insert(segmentID)
        }
        persist()
    }

    func toggleTag(_ tag: ReasonTag) {
        if selectedReasonTags.contains(tag) {
            selectedReasonTags.remove(tag)
        } else {
            selectedReasonTags.insert(tag)
        }
        persist()
    }

    func selectReason(_ tag: ReasonTag) {
        selectedReasonTags = [tag]
        persist()
    }

    func selectChoice(_ choiceID: String) {
        guard phase == .answer else { return }
        selectedChoiceId = choiceID
        persist()
    }

    func showHint() {
        hasUsedHint = true
        isHintPresented = true
        persist()
    }

    func performPrimaryAction() {
        guard canSubmit else { return }

        if phase == .answer,
           question.responseType == .selectSegments,
           !isGuidedExample,
           !question.recommendedReasonTags.isEmpty {
            phase = .reason
            persist()
            return
        }

        submit()
    }

    func submit() {
        let evaluation = evaluate()
        appViewModel.showResult(for: self, evaluation: evaluation)
    }

    private func evaluate() -> QuizEvaluation {
        QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: selectedSegmentIds,
            selectedReasonTags: selectedReasonTags,
            selectedChoiceId: selectedChoiceId,
            hintUsed: hasUsedHint,
            attemptNumber: attemptNumber
        )
    }

    func makeSnapshot(now: Date = Date()) -> QuizSessionSnapshot {
        QuizSessionSnapshot(
            questionID: question.id,
            phase: phase,
            selectedSegmentIDs: Array(selectedSegmentIds).sorted(),
            selectedReasonTags: Array(selectedReasonTags).sorted { $0.rawValue < $1.rawValue },
            selectedChoiceID: selectedChoiceId,
            hintUsed: hasUsedHint,
            attemptNumber: attemptNumber,
            updatedAt: now
        )
    }

    private func persist() {
        appViewModel.persist(session: self)
    }

    private func stableOrder(for tag: ReasonTag) -> UInt64 {
        (question.id + ":" + tag.rawValue).unicodeScalars.reduce(5381) { value, scalar in
            ((value << 5) &+ value) &+ UInt64(scalar.value)
        }
    }
}
