// todays-schedule.swift
//
// Run:      swift todays-schedule.swift
// Options:  swift todays-schedule.swift 3     (today plus the next 2 days)

import EventKit
import Foundation

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var granted = false
var accessError: Error?

// 1. Ask for calendar access
if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, error in
        granted = ok
        accessError = error
        semaphore.signal()
    }
} else {
    store.requestAccess(to: .event) { ok, error in
        granted = ok
        accessError = error
        semaphore.signal()
    }
}
semaphore.wait()

guard granted else {
    print("No calendar access.")
    if let accessError = accessError { print("Error: \(accessError.localizedDescription)") }
    print("Check System Settings > Privacy & Security > Calendars and allow your terminal app.")
    exit(1)
}

// 2. List the calendars macOS knows about, grouped by account.
//    If your work Google account isn't listed here, EventKit can't see it.
print("=== Calendars available ===")
let calendars = store.calendars(for: .event)
let bySource = Dictionary(grouping: calendars) { $0.source.title }
for source in bySource.keys.sorted() {
    print("\(source)")
    for cal in bySource[source]!.sorted(by: { $0.title < $1.title }) {
        print("  - \(cal.title)")
    }
}

// 3. List events for today (or the next N days)
let days = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 1) : 1
let calendar = Calendar.current
let start = calendar.startOfDay(for: Date())
let end = calendar.date(byAdding: .day, value: days, to: start)!

let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

let timeFormat = DateFormatter()
timeFormat.dateFormat = "HH:mm"
let dayFormat = DateFormatter()
dayFormat.dateFormat = "EEE d MMM"

print("\n=== Schedule ===")
if events.isEmpty {
    print("No events found.")
}

var currentDay = ""
for event in events {
    let day = dayFormat.string(from: event.startDate)
    if day != currentDay {
        currentDay = day
        print("\n\(day)")
    }

    let time = event.isAllDay
        ? "All day    "
        : "\(timeFormat.string(from: event.startDate))-\(timeFormat.string(from: event.endDate))"

    var line = "  \(time)  \(event.title ?? "(no title)")  [\(event.calendar.title) / \(event.calendar.source.title)]"
    if let location = event.location, !location.isEmpty {
        line += "  @ \(location)"
    }
    print(line)
}
