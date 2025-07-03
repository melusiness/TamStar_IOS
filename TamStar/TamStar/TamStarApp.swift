import SwiftUI
import Foundation

// MARK: - Model
struct Record: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
}

class RecordsStore: ObservableObject {
    @Published var records: [Record] = []
    @Published var intervalHours: Double = 3.0
    private let recordsKey = "records"
    private let intervalKey = "interval"
    init() { load() }
    func addRecord() {
        records.append(Record(id: UUID(), timestamp: Date()))
        save()
    }
    func delete(_ record: Record) {
        records.removeAll { $0.id == record.id }
        save()
    }
    func updateRecord(_ record: Record, newTimestamp: Date) {
        guard let idx = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[idx].timestamp = newTimestamp
        save()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
        UserDefaults.standard.set(intervalHours, forKey: intervalKey)
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let saved = try? JSONDecoder().decode([Record].self, from: data) {
            records = saved
        }
        let iv = UserDefaults.standard.double(forKey: intervalKey)
        intervalHours = iv == 0 ? 3.0 : iv
    }
}

// MARK: - App Entry
@main
struct TamStarApp: App {
    @StateObject private var store = RecordsStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                RecordsView()
                    .environmentObject(store)
                    .tabItem { Label("记录", systemImage: "plus.circle") }
                CalendarView()
                    .environmentObject(store)
                    .tabItem { Label("日历", systemImage: "calendar") }
            }
        }
    }
}

// MARK: - RecordsView
struct RecordsView: View {
    @EnvironmentObject var store: RecordsStore
    @State private var showIntervalSlider = false
    @State private var editingRecord: Record? = nil
    private var todayRecords: [Record] {
        store.records.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    private var todayAverageMinutes: Int? {
        let recs = todayRecords.sorted(by: { $0.timestamp < $1.timestamp })
        guard recs.count > 1 else { return nil }
        let intervals = zip(recs.dropFirst(), recs).map { Int($0.timestamp.timeIntervalSince($1.timestamp) / 60) }
        return intervals.reduce(0, +) / intervals.count
    }
    var body: some View {
        VStack(spacing: 16) {
            Text(Date(), formatter: dateFullFmt)
                .font(.headline)
                .padding(.top)
            Text("建议间隔：\(String(format: "%.1f", store.intervalHours)) 小时")
                .onTapGesture { showIntervalSlider.toggle() }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(todayRecords.sorted(by: { $0.timestamp < $1.timestamp })) { rec in
                        HStack {
                            Text(dateTimeFmt.string(from: rec.timestamp))
                            Spacer()
                            if let prev = prevRecord(rec) {
                                let diff = Int(rec.timestamp.timeIntervalSince(prev.timestamp) / 60)
                                let h = diff / 60, m = diff % 60
                                Text("+\(h)小时\(m)分钟").font(.caption)
                            }
                            Button { editingRecord = rec } label: {
                                Image(systemName: "pencil").foregroundColor(.blue)
                            }
                            Button { store.delete(rec) } label: {
                                Image(systemName: "trash").foregroundColor(.gray)
                            }
                        }.padding(.horizontal)
                    }
                }
            }
            if let avgMin = todayAverageMinutes,
               let last = todayRecords.sorted(by: { $0.timestamp < $1.timestamp }).last {
                let nextTime = last.timestamp.addingTimeInterval(TimeInterval(avgMin * 60))
                Text("推荐下次更换：\(dateTimeFmt.string(from: nextTime))")
                    .font(.subheadline)
                    .padding(.horizontal)
            } else {
                let nextTime = Date().addingTimeInterval(store.intervalHours * 3600)
                Text("推荐下次更换：\(dateTimeFmt.string(from: nextTime))")
                    .font(.subheadline)
                    .padding(.horizontal)
            }
            Spacer()
            Button(action: store.addRecord) {
                Text("记录更换")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .sheet(item: $editingRecord) { rec in
            EditRecordView(record: rec).environmentObject(store)
        }
        .sheet(isPresented: $showIntervalSlider) {
            VStack(spacing: 16) {
                Text("调整建议间隔：\(String(format: "%.1f", store.intervalHours)) 小时")
                    .font(.headline)
                Slider(value: $store.intervalHours, in: 0.5...10, step: 0.1)
                Button("保存并关闭") { showIntervalSlider = false }
            }.padding()
        }
    }
    private func prevRecord(_ record: Record) -> Record? {
        let recs = todayRecords.sorted(by: { $0.timestamp < $1.timestamp })
        guard let idx = recs.firstIndex(where: { $0.id == record.id }), idx > 0 else { return nil }
        return recs[idx-1]
    }
}

// MARK: - EditRecordView
struct EditRecordView: View {
    @EnvironmentObject var store: RecordsStore
    @Environment(\.dismiss) var dismiss
    let record: Record
    @State private var newTimestamp: Date
    init(record: Record) {
        self.record = record
        _newTimestamp = State(initialValue: record.timestamp)
    }
    var body: some View {
        VStack(spacing: 20) {
            DatePicker(
                "修改记录时间", selection: $newTimestamp,
                in: Calendar.current.startOfDay(for: record.timestamp)...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            Button("保存并关闭") {
                store.updateRecord(record, newTimestamp: newTimestamp)
                dismiss()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - CalendarView
struct CalendarView: View {
    @EnvironmentObject var store: RecordsStore
    @State private var currentDate = Date()
    @State private var selectedDate: Date? = nil
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }
    private var weeks: [[Date?]] {
        let startOfMonth = currentDate.startOfMonth
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        let offset = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day-1, to: startOfMonth))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            HStack { ForEach(["日","一","二","三","四","五","六"], id: \.self) { Text($0).frame(maxWidth: .infinity) } }
            ForEach(weeks.indices, id: \.self) { row in
                HStack {
                    ForEach(weeks[row].indices, id: \.self) { col in
                        let dateOpt = weeks[row][col]
                        VStack {
                            if let date = dateOpt {
                                Text("\(calendar.component(.day, from: date))")
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture { selectedDate = date }
                                HStack(spacing: 2) {
                                    ForEach(store.records.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.prefix(3), id: \.id) { _ in
                                        Image(systemName: "drop.fill").foregroundColor(.red)
                                    }
                                }
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                        .padding(4)
                        .background(
                            Group {
                                if let date = dateOpt, let sel = selectedDate, calendar.isDate(sel, inSameDayAs: date) {
                                    Color.red.opacity(0.2)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .cornerRadius(6)
                    }
                }
            }
            if let date = selectedDate {
                Divider().padding(.vertical)
                Text("记录详情：\(monthDetailTitle)\(calendar.component(.day, from: date))日")
                    .font(.headline).padding(.horizontal)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.records.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
                        .sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { rec in
                        Text(dateTimeFmt.string(from: rec.timestamp))
                    }
                }
            }
            Spacer()
        }
    }
    private func changeMonth(_ diff: Int) {
        currentDate = calendar.date(byAdding: .month, value: diff, to: currentDate)!; selectedDate = nil
    }
    private var monthTitle: String { let df = DateFormatter(); df.dateFormat = "yyyy 年 MM 月"; return df.string(from: currentDate) }
    private var monthDetailTitle: String { let df = DateFormatter(); df.dateFormat = "MM 月"; return df.string(from: currentDate) }
}

// MARK: - Formatters & Extensions
let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
let dateFullFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
let dateTimeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f }()

extension Date {
    var startOfMonth: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))! }
}
extension Calendar {
    func isDateInSameDay(_ date1: Date, _ date2: Date) -> Bool { isDate(date1, inSameDayAs: date2) }
}
