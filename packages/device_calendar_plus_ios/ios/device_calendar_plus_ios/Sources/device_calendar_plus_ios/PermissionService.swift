import EventKit

enum CalendarPermissionType {
  case write  // Need to write events (iOS 17+ writeOnly or fullAccess is fine)
  case full   // Need to read calendars/events (requires fullAccess)
}

class PermissionService {
  private let eventStore: EKEventStore
  
  // Permission status values matching CalendarPermissionStatus enum
  static let statusGranted = "granted"
  static let statusWriteOnly = "writeOnly"
  static let statusDenied = "denied"
  static let statusRestricted = "restricted"
  static let statusNotDetermined = "notDetermined"
  
  init(eventStore: EKEventStore) {
    self.eventStore = eventStore
  }
  
  /// Checks if calendar permissions are granted for the specified access level.
  /// - Parameter type: The type of access required (.write or .full)
  /// - Returns: true if the required permission level is granted
  func hasPermission(for type: CalendarPermissionType = .full) -> Bool {
    if #available(iOS 17.0, *) {
      let status = EKEventStore.authorizationStatus(for: .event)
      
      switch type {
      case .full:
        // For full access (reading), need fullAccess only
        switch status {
        case .fullAccess:
          return true
        case .writeOnly, .denied, .restricted, .notDetermined:
          return false
        @unknown default:
          return false
        }
        
      case .write:
        // For write-only operations, writeOnly or fullAccess is fine
        switch status {
        case .fullAccess, .writeOnly:
          return true
        case .denied, .restricted, .notDetermined:
          return false
        @unknown default:
          return false
        }
      }
    } else {
      // iOS 16 and below only has .authorized (which is full access)
      let status = EKEventStore.authorizationStatus(for: .event)
      switch status {
      case .authorized:
        return true
      case .denied, .restricted, .notDetermined:
        return false
      @unknown default:
        return false
      }
    }
  }
  
  // Info.plist usage-description keys. The declaration checks and the error
  // messages must name the same keys, so both go through these constants and
  // the shared descriptionExample map.
  private static let legacyUsageKey = "NSCalendarsUsageDescription"
  private static let fullAccessUsageKey = "NSCalendarsFullAccessUsageDescription"
  private static let writeOnlyUsageKey = "NSCalendarsWriteOnlyAccessUsageDescription"

  private static let descriptionExamples: [String: String] = [
    legacyUsageKey: "Access your calendar to view and manage events.",
    fullAccessUsageKey: "Full access to view and edit your calendar events.",
    writeOnlyUsageKey: "Add events without reading existing events.",
  ]

  private func isDescriptionDeclared(_ key: String) -> Bool {
    let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
    return !(value?.isEmpty ?? true)
  }

  private func missingDescriptionError(_ title: String, keys: [String]) -> PermissionError {
    var errorMessage = "\(title) not declared in Info.plist.\n\n"
    errorMessage += "Add the following to ios/Runner/Info.plist:"
    for key in keys {
      errorMessage += "\n<key>\(key)</key>"
      errorMessage += "\n<string>\(PermissionService.descriptionExamples[key] ?? "")</string>"
    }

    return PermissionError(code: PlatformExceptionCodes.permissionsNotDeclared, message: errorMessage)
  }

  private func missingWriteOnlyDescriptionError() -> PermissionError {
    missingDescriptionError(
      "Write-only calendar usage description",
      keys: [PermissionService.writeOnlyUsageKey])
  }

  private func missingFullAccessDescriptionError() -> PermissionError {
    missingDescriptionError(
      "Full-access calendar usage description",
      keys: [PermissionService.fullAccessUsageKey])
  }

  /// The no-keys-at-all error. Lists every key so following the advice once
  /// satisfies both the status guard and any later request on any OS version —
  /// naming only the legacy key would fix `hasPermissions` and then fail again
  /// on an iOS 17+ request, which demands the tier-specific keys.
  private func missingUsageDescriptionError() -> PermissionError {
    missingDescriptionError(
      "Calendar usage description",
      keys: [
        PermissionService.fullAccessUsageKey,
        PermissionService.writeOnlyUsageKey,
        PermissionService.legacyUsageKey,
      ])
  }

  /// Verifies the Info.plist declares the usage description the request needs.
  ///
  /// On iOS 17+ each request variant **requires** its own key: full access
  /// (`requestFullAccessToEvents`) needs `NSCalendarsFullAccessUsageDescription`
  /// and write-only needs `NSCalendarsWriteOnlyAccessUsageDescription` — the
  /// legacy `NSCalendarsUsageDescription` no longer satisfies either, and
  /// without the matching key the OS raises an exception, so we surface a
  /// clear error instead of crashing. iOS 16 and below uses only the legacy key.
  private func checkUsageDescriptionDeclared(writeOnly: Bool) -> PermissionError? {
    if #available(iOS 17.0, *) {
      if writeOnly {
        return isDescriptionDeclared(PermissionService.writeOnlyUsageKey)
          ? nil : missingWriteOnlyDescriptionError()
      }
      return isDescriptionDeclared(PermissionService.fullAccessUsageKey)
        ? nil : missingFullAccessDescriptionError()
    }

    return isDescriptionDeclared(PermissionService.legacyUsageKey)
      ? nil : missingDescriptionError(
        "Calendar usage description", keys: [PermissionService.legacyUsageKey])
  }
  
  private func getCurrentPermissionStatus() -> String {
    if #available(iOS 17.0, *) {
      let currentStatus = EKEventStore.authorizationStatus(for: .event)
      
      switch currentStatus {
      case .fullAccess:
        return PermissionService.statusGranted
      case .writeOnly:
        return PermissionService.statusWriteOnly
      case .denied:
        return PermissionService.statusDenied
      case .restricted:
        return PermissionService.statusRestricted
      case .notDetermined:
        return PermissionService.statusNotDetermined
      @unknown default:
        return PermissionService.statusDenied
      }
    } else {
      let currentStatus = EKEventStore.authorizationStatus(for: .event)
      
      switch currentStatus {
      case .authorized:
        return PermissionService.statusGranted
      case .denied:
        return PermissionService.statusDenied
      case .restricted:
        return PermissionService.statusRestricted
      case .notDetermined:
        return PermissionService.statusNotDetermined
      @unknown default:
        return PermissionService.statusDenied
      }
    }
  }
  
  func hasPermissions() -> Result<String, PermissionError> {
    // A status check triggers no prompt, so any declared calendar usage
    // description — legacy, full-access, or write-only — satisfies the
    // configuration guard. An add-only app that declares only the write-only
    // key can still check status.
    guard isDescriptionDeclared(PermissionService.legacyUsageKey)
      || isDescriptionDeclared(PermissionService.fullAccessUsageKey)
      || isDescriptionDeclared(PermissionService.writeOnlyUsageKey) else {
      return .failure(missingUsageDescriptionError())
    }

    return .success(getCurrentPermissionStatus())
  }
  
  /// Requests calendar access from the user.
  /// - Parameter writeOnly: when `true`, asks for add-only (write-only) access
  ///   where the OS supports it (iOS 17+). On iOS 16 and below write-only does
  ///   not exist, so the request falls back to full access regardless.
  func requestPermissions(
    writeOnly: Bool,
    completion: @escaping (Result<String, PermissionError>) -> Void
  ) {
    let currentStatus = getCurrentPermissionStatus()

    // Already hold a tier that satisfies the request? No prompt needed. Full
    // access satisfies any request; write-only satisfies a write-only ask — but
    // it does NOT satisfy a full ask, so a full request while only write-only is
    // held falls through to a request attempt below.
    let alreadySatisfied = currentStatus == PermissionService.statusGranted
      || (writeOnly && currentStatus == PermissionService.statusWriteOnly)

    // denied / restricted can't be changed from inside the app — the user must
    // use Settings — so report them as-is instead of firing a no-op request.
    let terminal = currentStatus == PermissionService.statusDenied
      || currentStatus == PermissionService.statusRestricted

    if alreadySatisfied || terminal {
      completion(.success(currentStatus))
      return
    }

    // The usage-description key is only needed once we actually fire an OS
    // request, so the check sits after the early returns — an app that ships
    // without the (iOS 17+) tier key must still get its already-granted or
    // terminal status back rather than a configuration error.
    if let error = checkUsageDescriptionDeclared(writeOnly: writeOnly) {
      completion(.failure(error))
      return
    }

    // Otherwise attempt the request. This prompts on a fresh notDetermined, and
    // also on a full request while only write-only is held — iOS re-presents the
    // dialog asking for full access and upgrades the app in-app if the user
    // agrees. On a non-grant we re-read the real status so the caller still sees
    // the tier they actually hold (e.g. writeOnly), not a misleading denied.
    // Report the tier we asked for on a grant; on a non-grant re-read the real
    // status. One handler serves all three request variants.
    if #available(iOS 17.0, *) {
      let grantedStatus = writeOnly
        ? PermissionService.statusWriteOnly
        : PermissionService.statusGranted
      let handler: (Bool, Error?) -> Void = { granted, _ in
        completion(.success(granted ? grantedStatus : self.getCurrentPermissionStatus()))
      }
      if writeOnly {
        eventStore.requestWriteOnlyAccessToEvents(completion: handler)
      } else {
        eventStore.requestFullAccessToEvents(completion: handler)
      }
    } else {
      // iOS 16 and below: only full access exists, so any grant is full access.
      let handler: (Bool, Error?) -> Void = { granted, _ in
        completion(.success(granted ? PermissionService.statusGranted : self.getCurrentPermissionStatus()))
      }
      eventStore.requestAccess(to: .event, completion: handler)
    }
  }
}

struct PermissionError: Error {
  let code: String
  let message: String
}

