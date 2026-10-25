import SwiftUI

/// Gemma — Twin's assistant mascot. A modern nod to the old Office
/// paperclip ("gem" in Swedish): clean geometry, no clip-art. Her
/// head is split in two halves like Twin's panes, one eye in each.
/// Idle she breathes and blinks; thinking, her antenna pulses and
/// her eyes search. Respects Reduce Motion (stands still).
struct GemmaRobotView: View {
    enum State {
        case idle
        case thinking
    }

    var state: State = .idle
    /// Design is drawn in a 100×100 box and scaled to this size.
    var size: CGFloat = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                robot(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    robot(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Gemma, Twin's assistant")
    }

    private func robot(time: TimeInterval) -> some View {
        let s = size / 100
        let bob = reduceMotion ? 0 : sin(time * 1.6) * 1.6
        // Blink: eyes close for the last 0.15 s of every 3.4 s cycle.
        let cycle = time.truncatingRemainder(dividingBy: 3.4)
        let eyeOpen: CGFloat = cycle > 3.25 ? 0.12 : 1
        // Thinking: pupils wander; idle: they rest centred.
        let pupilDX: CGFloat = state == .thinking && !reduceMotion ? CGFloat(sin(time * 2.2)) * 2.2 : 0
        let pupilDY: CGFloat = state == .thinking ? -1.2 : 0
        let antennaPulse = state == .thinking && !reduceMotion
            ? (sin(time * 6) * 0.5 + 0.5) : 0

        return ZStack {
            // Antenna
            Capsule()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 3 * s, height: 14 * s)
                .offset(y: -40 * s + bob * s)
            Circle()
                .fill(Color.accentColor.opacity(0.55 + 0.45 * antennaPulse))
                .frame(width: (9 + 3 * antennaPulse) * s, height: (9 + 3 * antennaPulse) * s)
                .offset(y: -48 * s + bob * s)

            // Side pods (pane handles)
            RoundedRectangle(cornerRadius: 3 * s)
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 6 * s, height: 18 * s)
                .offset(x: -35 * s, y: -18 * s + bob * s)
            RoundedRectangle(cornerRadius: 3 * s)
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 6 * s, height: 18 * s)
                .offset(x: 35 * s, y: -18 * s + bob * s)

            // Head: two panes
            HStack(spacing: 0) {
                Rectangle().fill(Color.accentColor.opacity(0.28))
                Rectangle().fill(Color.accentColor.opacity(0.12))
            }
            .frame(width: 64 * s, height: 50 * s)
            .clipShape(RoundedRectangle(cornerRadius: 14 * s))
            .overlay(
                RoundedRectangle(cornerRadius: 14 * s)
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1.4 * s)
            )
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 1.4 * s, height: 50 * s)
            )
            .offset(y: -18 * s + bob * s)

            // Eyes — one per pane
            eye(scaleY: eyeOpen, s: s)
                .offset(x: -16 * s + pupilDX * s, y: -20 * s + bob * s + pupilDY * s)
            eye(scaleY: eyeOpen, s: s)
                .offset(x: 16 * s + pupilDX * s, y: -20 * s + bob * s + pupilDY * s)

            // Mouth: calm line; thinking makes a small "o"
            if state == .thinking {
                Circle()
                    .stroke(Color.primary.opacity(0.75), lineWidth: 1.8 * s)
                    .frame(width: 8 * s, height: 8 * s)
                    .offset(y: -6 * s + bob * s)
            } else {
                Capsule()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 14 * s, height: 2.4 * s)
                    .offset(y: -6 * s + bob * s)
            }

            // Body: the paperclip homage — one clean wire loop
            RoundedRectangle(cornerRadius: 8 * s)
                .stroke(Color.accentColor.opacity(0.7), lineWidth: 3 * s)
                .frame(width: 26 * s, height: 30 * s)
                .offset(y: 22 * s + bob * 0.4 * s)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6 * s, height: 6 * s)
                .offset(y: 22 * s + bob * 0.4 * s)
        }
    }

    private func eye(scaleY: CGFloat, s: CGFloat) -> some View {
        Circle()
            .fill(Color.primary.opacity(0.85))
            .frame(width: 8 * s, height: 8 * s)
            .scaleEffect(x: 1, y: scaleY)
    }
}
