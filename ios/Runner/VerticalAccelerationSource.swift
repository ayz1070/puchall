import CoreMotion
import Foundation

/// 중력이 제거된 "수직 선형 가속도"(m/s², 위쪽이 양수)를 만들어 내보낸다.
///
/// `CMDeviceMotion`은 센서 퓨전으로 계산한 `userAcceleration`(중력 제거)과
/// `gravity`(중력 방향)를 **같은 패킷**으로 주므로 두 값의 시간 정렬이 보장된다.
/// 원시 가속도계를 쓰는 것보다 정확하다.
///
/// 측정과 기준치 캘리브레이션이 같은 신호를 보도록 두 경로 모두 이 클래스를 쓴다.
final class VerticalAccelerationSource {
    private let motionManager: CMMotionManager
    private let onSample: (_ verticalAcceleration: Double, _ timestampMs: Double) -> Void

    /// 50Hz. Android의 SAMPLING_PERIOD_US(20,000µs)와 같은 간격.
    static let sampleInterval = 1.0 / 50.0

    private static let gravity = 9.80665

    init(
        motionManager: CMMotionManager,
        onSample: @escaping (_ verticalAcceleration: Double, _ timestampMs: Double) -> Void
    ) {
        self.motionManager = motionManager
        self.onSample = onSample
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = Self.sampleInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func handle(_ motion: CMDeviceMotion) {
        let gravityVector = motion.gravity
        let magnitude = sqrt(
            gravityVector.x * gravityVector.x
                + gravityVector.y * gravityVector.y
                + gravityVector.z * gravityVector.z
        )
        guard magnitude > 1e-3 else { return }

        let userAcceleration = motion.userAcceleration
        let dot =
            userAcceleration.x * gravityVector.x
            + userAcceleration.y * gravityVector.y
            + userAcceleration.z * gravityVector.z

        // iOS의 gravity 벡터는 지구 쪽을 가리킨다(평평히 두면 (0,0,-1)).
        // 따라서 부호를 뒤집어야 "위쪽이 양수"가 된다.
        // userAcceleration 단위가 g이므로 m/s²로 환산한다.
        let verticalAcceleration = -(dot / magnitude) * Self.gravity

        // CMDeviceMotion.timestamp는 부팅 기준 초. 간격 계산에만 쓴다.
        onSample(verticalAcceleration, motion.timestamp * 1000.0)
    }
}
