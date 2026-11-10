//
//  NetworkShares.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import NetFS
import Observation

@MainActor
@Observable
final class NetworkShares {
    static let shared = NetworkShares()

    private(set) var mountPoints: [String: URL] = [:]
    private(set) var connecting: Set<URL> = []
    private(set) var revision = 0
    var failure: String?

    var shares: [URL] {
        (SettingsStore.shared.settings.shares ?? []).compactMap(URL.init(string:))
    }

    var listedMountPoints: Set<String> {
        Set(shares.compactMap { mountPoint(of: $0)?.folderKey })
    }

    private init() {
        let center = NSWorkspace.shared.notificationCenter

        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            _ = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in await NetworkShares.shared.refresh() }
            }
        }

        Task { await refresh() }
    }

    func mountPoint(of share: URL) -> URL? {
        mountPoints[Self.key(share)]
    }

    func share(withID id: String) -> URL? {
        shares.first { $0.absoluteString == id }
    }

    func refresh() async {
        let volumes = await Self.remoteVolumes()

        mountPoints = Dictionary(volumes.map { (Self.key($0.address), $0.point) }) { first, _ in first }

        if SettingsStore.shared.settings.shares == nil, !volumes.isEmpty {
            SettingsStore.shared.settings.shares = volumes
                .map(\.address)
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map(\.absoluteString)
            SettingsStore.shared.save()
        }

        revision += 1
    }

    func open(_ share: URL) async -> URL? {
        if let point = mountPoint(of: share) {
            return point
        }

        guard !connecting.contains(share) else { return nil }

        connecting.insert(share)
        defer { connecting.remove(share) }

        let status = await Self.mount(share)

        guard status != 0 else {
            await refresh()
            return mountPoint(of: share)
        }

        // cancelling the sign-in window is not a failure
        if status != -128 {
            failure = Self.describe(status, connecting: share)
        }

        return nil
    }

    func eject(_ share: URL) async {
        guard let point = mountPoint(of: share) else { return }

        do {
            try await FileManager.default.unmountVolume(at: point)
        } catch {
            failure = "\u{201C}\(share.lastPathComponent)\u{201D} could not be ejected: \(error.localizedDescription)"
        }

        await refresh()
    }

    // a stale mount after the nas restarts only recovers by mounting again
    func reconnect(_ share: URL) async {
        await eject(share)
        _ = await open(share)
    }

    // shares match on server and share name; the user name and letter case can differ
    static func key(_ address: URL) -> String {
        "\(address.host() ?? "")\(address.path(percentEncoded: false))".lowercased()
    }

    @concurrent
    private static func remoteVolumes() async -> [(address: URL, point: URL)] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeURLForRemountingKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        return volumes.compactMap { volume in
            guard let values = try? volume.resourceValues(forKeys: Set(keys)),
                  values.volumeIsLocal == false,
                  let address = values.volumeURLForRemounting else { return nil }

            return (address, volume)
        }
    }

    // mounts under /Volumes like finder; macos shows its own sign-in window when keychain has no password
    @concurrent
    private static func mount(_ share: URL) async -> Int32 {
        NetFSMountURLSync(share as CFURL, nil, nil, nil, nil, nil, nil)
    }

    private static func describe(_ status: Int32, connecting share: URL) -> String {
        let name = "\u{201C}\(share.lastPathComponent)\u{201D}"
        let server = share.host() ?? "The server"

        switch status {
        case ETIMEDOUT, EHOSTUNREACH, EHOSTDOWN, ENETUNREACH, ECONNREFUSED:
            return "\(server) could not be reached, so \(name) is still offline."
        case EAUTH, EACCES, EPERM:
            return "\(server) did not accept the user name or password for \(name)."
        case ENOENT:
            return "\(server) has no share named \(name)."
        default:
            let reason = status > 0 ? String(cString: strerror(status)) : "error \(status)"

            return "\(name) could not be connected: \(reason)."
        }
    }
}
