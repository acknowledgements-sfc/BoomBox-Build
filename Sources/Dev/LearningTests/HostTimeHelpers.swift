#if DEBUG
import Foundation

enum HostTimeHelpers {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func machAbsoluteTime() -> UInt64 {
        mach_absolute_time()
    }

    static func hostTime(offsetSeconds: Double, from now: UInt64 = mach_absolute_time()) -> UInt64 {
        let offsetNanos = UInt64(offsetSeconds * 1_000_000_000)
        let offsetMach = offsetNanos * UInt64(timebase.denom) / UInt64(timebase.numer)
        return now + offsetMach
    }

    static func hostTimeDifferenceSeconds(scheduled: UInt64, actual: UInt64) -> Double {
        let diffMach: Int64
        if actual >= scheduled {
            diffMach = Int64(actual - scheduled)
        } else {
            diffMach = -Int64(scheduled - actual)
        }
        let nanos = Double(diffMach) * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000_000.0
    }
}
#endif
