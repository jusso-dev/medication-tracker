import Foundation
import Observation
import SwiftData
@preconcurrency import UserNotifications

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    static let reminderCategory = "MEDICATION_REMINDER"
    static let takeAction = "TAKE_MEDICATION"
    static let skipAction = "SKIP_MEDICATION"
    static let snoozeAction = "SNOOZE_MEDICATION"

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private var modelContainer: ModelContainer?
    @ObservationIgnored private var notificationDelegate: MedicationNotificationDelegate?

    private init() {}

    func install(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        if notificationDelegate == nil {
            notificationDelegate = MedicationNotificationDelegate(owner: self)
        }
        center.delegate = notificationDelegate
        registerCategories()
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func rebuildAll(context: ModelContext) async {
        let pending = await center.pendingNotificationRequests()
        let medicationIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("dose.") || $0.hasPrefix("snooze.") }
        center.removePendingNotificationRequests(withIdentifiers: medicationIDs)

        let medicines = (try? context.fetch(FetchDescriptor<Medicine>())) ?? []
        let active = medicines.filter {
            $0.status == .active && !$0.asNeeded && $0.remindersOn
        }
        let leadTime = UserDefaults.standard.integer(forKey: SettingsKeys.reminderLeadTime)
        let now = Date.now

        let snoozeCandidates = active.flatMap { medicine in
            medicine.doseEvents.compactMap { event -> NotificationCandidate? in
                guard event.outcome == .snoozed,
                      let originalDate = event.scheduledAt,
                      let snoozedUntil = event.takenAt,
                      snoozedUntil > now else {
                    return nil
                }
                let request = reminderRequest(
                    for: medicine,
                    scheduledAt: originalDate,
                    fireDate: snoozedUntil,
                    isSnooze: true
                )
                return NotificationCandidate(request: request, fireDate: snoozedUntil)
            }
        }

        var recurringRequests: [NotificationCandidate] = []
        var finiteRequests: [NotificationCandidate] = []

        for medicine in active {
            if medicine.endDate == nil && medicine.startDate.startOfDay <= now.startOfDay {
                recurringRequests += recurringCandidates(
                    for: medicine,
                    leadTime: leadTime,
                    after: now
                )
                continue
            }

            let schedule = MedicationSchedule(
                daysOfWeek: medicine.daysOfWeek,
                times: medicine.times,
                startDate: medicine.startDate,
                endDate: medicine.endDate,
                leadTimeMinutes: leadTime
            )
            finiteRequests += ScheduleCalculator.doseDates(
                for: schedule,
                after: now,
                limit: 60
            ).compactMap { scheduledAt -> NotificationCandidate? in
                guard DoseService.event(for: medicine, scheduledAt: scheduledAt) == nil,
                      DoseService.snoozedEvent(for: medicine, scheduledAt: scheduledAt) == nil else {
                    return nil
                }
                guard let fireDate = Calendar.current.date(
                    byAdding: .minute,
                    value: -leadTime,
                    to: scheduledAt
                ) else {
                    return nil
                }
                let request = reminderRequest(
                    for: medicine,
                    scheduledAt: scheduledAt,
                    fireDate: fireDate,
                    isSnooze: false
                )
                return NotificationCandidate(request: request, fireDate: fireDate)
            }
        }

        let priority = (snoozeCandidates + recurringRequests)
            .sorted { $0.fireDate < $1.fireDate }
        let selectedPriority = Array(priority.prefix(60))
        let remainingCapacity = max(0, 60 - selectedPriority.count)
        let rollingFinite = Array(finiteRequests
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(remainingCapacity))

        for candidate in selectedPriority + rollingFinite {
            try? await center.add(candidate.request)
        }
    }

    @discardableResult
    func scheduleLowStockNotification(for medicine: Medicine) async -> Bool {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Running low"
        content.body = "\(medicine.displayName) is at or below your refill threshold."
        content.sound = .default
        content.userInfo = ["medicineID": medicine.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "refill.\(medicine.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(request)
            medicine.lowStockNotificationSent = true
            try modelContainer?.mainContext.save()
            return true
        } catch {
            return false
        }
    }

    func removeNotifications(for medicine: Medicine) async {
        await removeNotifications(forMedicineID: medicine.id)
    }

    func removeNotifications(forMedicineID medicineID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let pendingIdentifiers = pending.map(\.identifier).filter {
            $0.contains(medicineID.uuidString)
        }
        let delivered = await center.deliveredNotifications()
        let deliveredIdentifiers = delivered.compactMap { notification in
            let value = notification.request.content.userInfo["medicineID"] as? String
            return value == medicineID.uuidString ? notification.request.identifier : nil
        }
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
    }

    func handle(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let identifier = userInfo["medicineID"] as? String,
              let medicineID = UUID(uuidString: identifier) else {
            return
        }

        let scheduledAt = scheduledDate(for: response.notification)

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            AppRouter.shared.openToday(medicineID: medicineID, scheduledAt: scheduledAt)
        case Self.takeAction:
            await recordNotificationAction(
                medicineID: medicineID,
                outcome: (scheduledAt.map { Date.now > $0.addingTimeInterval(60) } ?? false) ? .late : .taken,
                scheduledAt: scheduledAt
            )
        case Self.skipAction:
            await recordNotificationAction(
                medicineID: medicineID,
                outcome: .skipped,
                scheduledAt: scheduledAt
            )
        case Self.snoozeAction:
            guard let scheduledAt else { return }
            await snooze(medicineID: medicineID, scheduledAt: scheduledAt)
        default:
            break
        }
    }

    private func registerCategories() {
        let take = UNNotificationAction(
            identifier: Self.takeAction,
            title: "Take",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: Self.skipAction,
            title: "Skip",
            options: [.destructive]
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: "Snooze",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.reminderCategory,
            actions: [take, skip, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func reminderRequest(
        for medicine: Medicine,
        scheduledAt: Date,
        fireDate: Date,
        isSnooze: Bool
    ) -> UNNotificationRequest {
        let content = reminderContent(for: medicine)
        content.userInfo = [
            "medicineID": medicine.id.uuidString,
            "scheduledAt": scheduledAt.timeIntervalSince1970,
            "snoozed": isSnooze
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let prefix = isSnooze ? "snooze" : "dose"
        return UNNotificationRequest(
            identifier: "\(prefix).\(medicine.id.uuidString).\(Int(scheduledAt.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
    }

    private func recurringCandidates(
        for medicine: Medicine,
        leadTime: Int,
        after now: Date
    ) -> [NotificationCandidate] {
        let calendar = Calendar.current
        if Set(medicine.daysOfWeek) == Set(1...7) {
            return medicine.times.compactMap { minutes -> NotificationCandidate? in
                let fireMinutes = ((minutes - leadTime) % 1_440 + 1_440) % 1_440
                var components = DateComponents()
                components.hour = fireMinutes / 60
                components.minute = fireMinutes % 60
                guard let nextFire = calendar.nextDate(
                    after: now,
                    matching: components,
                    matchingPolicy: .nextTime
                ) else {
                    return nil
                }

                let content = reminderContent(for: medicine)
                content.userInfo = [
                    "medicineID": medicine.id.uuidString,
                    "leadTime": leadTime,
                    "scheduledMinutes": minutes
                ]
                let request = UNNotificationRequest(
                    identifier: "dose.\(medicine.id.uuidString).daily.\(minutes)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: components,
                        repeats: true
                    )
                )
                return NotificationCandidate(request: request, fireDate: nextFire)
            }
        }

        return medicine.daysOfWeek.flatMap { weekday in
            medicine.times.compactMap { minutes -> NotificationCandidate? in
                let fireTotal = minutes - leadTime
                let dayOffset = fireTotal < 0 ? -1 : 0
                let fireMinutes = ((fireTotal % 1_440) + 1_440) % 1_440
                let fireWeekday = ((weekday - 1 + dayOffset) % 7 + 7) % 7 + 1
                var components = DateComponents()
                components.weekday = fireWeekday
                components.hour = fireMinutes / 60
                components.minute = fireMinutes % 60

                guard let nextFire = calendar.nextDate(
                    after: now,
                    matching: components,
                    matchingPolicy: .nextTime
                ) else {
                    return nil
                }

                let content = reminderContent(for: medicine)
                content.userInfo = [
                    "medicineID": medicine.id.uuidString,
                    "leadTime": leadTime,
                    "scheduledWeekday": weekday,
                    "scheduledMinutes": minutes
                ]
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: true
                )
                let identifier = "dose.\(medicine.id.uuidString).weekly.\(weekday).\(minutes)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                return NotificationCandidate(request: request, fireDate: nextFire)
            }
        }
    }

    private func reminderContent(for medicine: Medicine) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = medicine.displayName
        content.body = "Time to take your dose"
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategory
        content.threadIdentifier = "medication-reminders"
        return content
    }

    private func scheduledDate(for notification: UNNotification) -> Date? {
        let userInfo = notification.request.content.userInfo
        if let timestamp = userInfo["scheduledAt"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let leadTime = userInfo["leadTime"] as? Int {
            return Calendar.current.date(
                byAdding: .minute,
                value: leadTime,
                to: notification.date
            )
        }
        return nil
    }

    func removeDoseNotification(
        medicineID: UUID,
        scheduledAt: Date
    ) async {
        let timestamp = Int(scheduledAt.timeIntervalSince1970)
        center.removePendingNotificationRequests(withIdentifiers: [
            "dose.\(medicineID.uuidString).\(timestamp)",
            "snooze.\(medicineID.uuidString).\(timestamp)"
        ])

        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.compactMap { notification -> String? in
            guard notification.request.content.userInfo["medicineID"] as? String
                    == medicineID.uuidString,
                  let deliveredDose = scheduledDate(for: notification),
                  abs(deliveredDose.timeIntervalSince(scheduledAt)) < 60 else {
                return nil
            }
            return notification.request.identifier
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func recordNotificationAction(
        medicineID: UUID,
        outcome: DoseOutcome,
        scheduledAt: Date?
    ) async {
        guard let context = modelContainer?.mainContext,
              let medicine = fetchMedicine(id: medicineID, context: context),
              medicine.status == .active else {
            return
        }

        let reachedLowStock = (try? DoseService.record(
            medicine: medicine,
            outcome: outcome,
            scheduledAt: scheduledAt,
            context: context
        )) ?? false
        if reachedLowStock {
            _ = await scheduleLowStockNotification(for: medicine)
        }
        if let scheduledAt {
            await removeDoseNotification(
                medicineID: medicineID,
                scheduledAt: scheduledAt
            )
        }
    }

    func snooze(medicineID: UUID, scheduledAt: Date) async {
        guard let context = modelContainer?.mainContext,
              let medicine = fetchMedicine(id: medicineID, context: context),
              medicine.status == .active,
              DoseService.snoozedEvent(for: medicine, scheduledAt: scheduledAt) == nil else {
            return
        }

        let length = max(1, UserDefaults.standard.integer(forKey: SettingsKeys.snoozeMinutes))
        let minutes = length == 1 ? 10 : length
        let snoozedUntil = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try DoseService.snooze(
                medicine: medicine,
                scheduledAt: scheduledAt,
                until: snoozedUntil,
                context: context
            )
            let request = reminderRequest(
                for: medicine,
                scheduledAt: scheduledAt,
                fireDate: snoozedUntil,
                isSnooze: true
            )
            try await center.add(request)
            await removeDeliveredDoseNotification(
                medicineID: medicineID,
                scheduledAt: scheduledAt
            )
        } catch {
            return
        }
    }

    private func removeDeliveredDoseNotification(
        medicineID: UUID,
        scheduledAt: Date
    ) async {
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.compactMap { notification -> String? in
            guard notification.request.content.userInfo["medicineID"] as? String
                    == medicineID.uuidString,
                  let deliveredDose = scheduledDate(for: notification),
                  abs(deliveredDose.timeIntervalSince(scheduledAt)) < 60 else {
                return nil
            }
            return notification.request.identifier
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func fetchMedicine(id: UUID, context: ModelContext) -> Medicine? {
        let all = (try? context.fetch(FetchDescriptor<Medicine>())) ?? []
        return all.first { $0.id == id }
    }
}

private struct NotificationCandidate {
    let request: UNNotificationRequest
    let fireDate: Date
}

private final class MedicationNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private weak var owner: NotificationManager?

    init(owner: NotificationManager) {
        self.owner = owner
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await owner?.handle(response)
    }
}

enum SettingsKeys {
    static let reminderLeadTime = "reminderLeadTime"
    static let snoozeMinutes = "snoozeMinutes"
    static let appLockEnabled = "appLockEnabled"
}
