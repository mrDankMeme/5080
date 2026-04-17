import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class VoiceGenResultSceneViewModel: NSObject, ObservableObject {
    enum SaveState: Equatable {
        case download
        case saving(dotCount: Int)
        case saved
    }

    enum SaveToast: Equatable {
        case saved
        case failed
    }

    @Published private(set) var saveState: SaveState = .download
    @Published private(set) var toast: SaveToast?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    let audioURL: URL
    let displayTitle: String

    private var saveTask: Task<Void, Never>?
    private var dotsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var isPlayerConfigured = false
    private var baseWaveformSamples: [CGFloat]

    init(audioURL: URL, displayTitle: String) {
        self.audioURL = audioURL
        self.displayTitle = displayTitle

        let rawData = (try? Data(contentsOf: audioURL)) ?? Data()
        self.baseWaveformSamples = Self.makeWaveformSamples(from: rawData)

        super.init()
    }

    deinit {
        saveTask?.cancel()
        dotsTask?.cancel()
        toastTask?.cancel()
        progressTask?.cancel()
        audioPlayer?.stop()
    }

    var saveButtonTitle: String {
        switch saveState {
        case .download:
            return "Download"
        case .saving(let dotCount):
            let dots = String(repeating: ".", count: max(1, min(3, dotCount)))
            return "Saving\(dots)"
        case .saved:
            return "Saved"
        }
    }

    var isSaveDisabled: Bool {
        if case .saving = saveState {
            return true
        }
        return false
    }

    var saveButtonOpacity: CGFloat {
        switch saveState {
        case .saving:
            return 0.5
        default:
            return 1.0
        }
    }

    var playbackProgress: CGFloat {
        guard duration > 0 else { return 0 }
        return min(1, max(0, CGFloat(currentTime / duration)))
    }

    var currentTimeText: String {
        formatTime(currentTime)
    }

    var durationText: String {
        formatTime(duration)
    }

    var playButtonAssetName: String {
        isPlaying ? "vg_stop_48" : "vg_play_48"
    }

    var toastTitle: String {
        toast == .saved ? "Saved to Files" : "Failed to save"
    }

    func onAppear() {
        configurePlayerIfNeeded()
    }

    func onDisappear() {
        stopPlayback()
    }

    func togglePlayback() {
        configurePlayerIfNeeded()

        guard let audioPlayer else { return }

        if isPlaying {
            audioPlayer.pause()
            isPlaying = false
            stopProgressTracking()
            return
        }

        audioPlayer.play()
        isPlaying = true
        startProgressTracking()
    }

    func skipBackward() {
        configurePlayerIfNeeded()
        guard let audioPlayer else { return }

        let nextTime = max(0, audioPlayer.currentTime - 10)
        audioPlayer.currentTime = nextTime
        currentTime = nextTime
    }

    func skipForward() {
        configurePlayerIfNeeded()
        guard let audioPlayer else { return }

        let nextTime = min(audioPlayer.duration, audioPlayer.currentTime + 10)
        audioPlayer.currentTime = nextTime
        currentTime = nextTime
    }

    func waveformSamples(for barCount: Int) -> [CGFloat] {
        guard barCount > 0 else { return [] }
        guard !baseWaveformSamples.isEmpty else {
            return Array(repeating: 0.35, count: barCount)
        }

        if baseWaveformSamples.count == barCount {
            return baseWaveformSamples
        }

        if baseWaveformSamples.count < barCount {
            return (0..<barCount).map { baseWaveformSamples[$0 % baseWaveformSamples.count] }
        }

        let step = Double(baseWaveformSamples.count - 1) / Double(max(1, barCount - 1))

        return (0..<barCount).map { index in
            let position = Double(index) * step
            let low = Int(position)
            let high = min(baseWaveformSamples.count - 1, low + 1)
            let fraction = CGFloat(position - Double(low))
            let lowValue = baseWaveformSamples[low]
            let highValue = baseWaveformSamples[high]
            return lowValue + (highValue - lowValue) * fraction
        }
    }

    func saveToFiles() {
        guard !isSaveDisabled else { return }

        saveTask?.cancel()
        dotsTask?.cancel()

        saveState = .saving(dotCount: 1)
        startDotsAnimation()

        saveTask = Task { [weak self] in
            guard let self else { return }

            do {
                try self.performSaveToFiles()
                self.dotsTask?.cancel()
                self.saveState = .saved
                self.showToast(.saved)
            } catch {
                self.dotsTask?.cancel()
                self.saveState = .download
                self.showToast(.failed)
            }
        }
    }

    private func configurePlayerIfNeeded() {
        guard !isPlayerConfigured else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.delegate = self
            player.prepareToPlay()

            audioPlayer = player
            duration = max(0, player.duration)
            currentTime = 0
            isPlayerConfigured = true
        } catch {
            showToast(.failed)
        }
    }

    private func stopPlayback() {
        guard let audioPlayer else { return }

        audioPlayer.stop()
        audioPlayer.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopProgressTracking()
    }

    private func startProgressTracking() {
        progressTask?.cancel()

        progressTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }

                if let audioPlayer = self.audioPlayer {
                    self.currentTime = max(0, min(audioPlayer.currentTime, audioPlayer.duration))
                }
            }
        }
    }

    private func stopProgressTracking() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func startDotsAnimation() {
        dotsTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }

                if case .saving(let dotCount) = self.saveState {
                    let next = dotCount % 3 + 1
                    self.saveState = .saving(dotCount: next)
                }
            }
        }
    }

    private func showToast(_ toast: SaveToast) {
        toastTask?.cancel()
        self.toast = toast

        toastTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.toast = nil
            }
        }
    }

    private func performSaveToFiles() throws {
        let fileManager = FileManager.default

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let folderURL = documentsURL.appendingPathComponent("VoiceGen", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileExtension = audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension
        let sanitizedBase = Self.sanitizedFileName(displayTitle)
        let baseName = sanitizedBase.isEmpty ? "voiceover" : sanitizedBase

        var destinationURL = folderURL.appendingPathComponent("\(baseName).\(fileExtension)")
        var suffix = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            destinationURL = folderURL.appendingPathComponent("\(baseName)_\(suffix).\(fileExtension)")
            suffix += 1
        }

        try fileManager.copyItem(at: audioURL, to: destinationURL)
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func makeWaveformSamples(from data: Data, targetSamples: Int = 220) -> [CGFloat] {
        guard !data.isEmpty else {
            return Array(repeating: 0.35, count: targetSamples)
        }

        let chunkSize = max(1, data.count / targetSamples)
        var values: [CGFloat] = []
        values.reserveCapacity(targetSamples)

        var index = 0
        while index < data.count {
            let end = min(data.count, index + chunkSize)
            let slice = data[index..<end]

            var total: Double = 0
            for byte in slice {
                let centered = abs(Double(Int(byte) - 128))
                total += centered / 128.0
            }

            let average = total / Double(max(1, slice.count))
            let normalized = max(0.18, min(1.0, average))
            values.append(CGFloat(normalized))

            index = end
        }

        if values.isEmpty {
            return Array(repeating: 0.35, count: targetSamples)
        }

        return values
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }

        let collapsed = String(filtered)
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_ "))

        return String(collapsed.prefix(48))
    }
}

extension VoiceGenResultSceneViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.stopProgressTracking()
            self.currentTime = self.duration
        }
    }
}
