import CoreAudio
import Foundation

/// 系统麦克风静音控制
enum MicController {
    /// 设置默认输入设备的静音状态
    static func setMuted(_ muted: Bool) {
        let deviceID = getDefaultInputDevice()
        guard deviceID != kAudioObjectUnknown else {
            print("[MicController] 未找到默认输入设备")
            return
        }

        var mute: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0, nil,
            UInt32(MemoryLayout<UInt32>.size),
            &mute
        )

        if status != noErr {
            // 部分设备不支持 mute 属性，改用音量控制
            setInputVolume(deviceID: deviceID, volume: muted ? 0.0 : 1.0)
        }
    }

    /// 获取当前麦克风是否静音
    static func isMuted() -> Bool {
        let deviceID = getDefaultInputDevice()
        guard deviceID != kAudioObjectUnknown else { return false }

        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mute)
        if status != noErr {
            // 回退到检查音量
            return getInputVolume(deviceID: deviceID) == 0.0
        }
        return mute != 0
    }

    // MARK: - 内部方法

    private static func getDefaultInputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private static func setInputVolume(deviceID: AudioDeviceID, volume: Float32) {
        var vol = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
    }

    private static func getInputVolume(deviceID: AudioDeviceID) -> Float32 {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return volume
    }
}
